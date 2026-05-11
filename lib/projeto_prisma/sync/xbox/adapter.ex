defmodule ProjetoPrisma.Sync.Xbox.Adapter do
  @moduledoc """
  Adapter Xbox Live: titlehub para a biblioteca, Achievements service por título.

  Reaproveita o cache de XSTS de `ProjetoPrisma.Sync.Xbox.Session`. Em 401
  invalida o cache e tenta de novo uma vez.
  """

  @behaviour ProjetoPrisma.Sync.PlatformBehaviour

  alias ProjetoPrisma.Sync.Xbox.{Client, Session}
  require Logger

  @never_unlocked "0001-01-01T00:00:00.0000000Z"

  @impl true
  def fetch_games(%{external_user_id: xuid} = account) do
    with_auth(account, fn auth_header ->
      case Client.get_titles(xuid, auth_header) do
        {:ok, %{status: 200, body: body}} ->
          games =
            body
            |> Map.get("titles", [])
            |> List.wrap()
            |> Enum.map(&normalize_game/1)
            |> Enum.reject(&is_nil/1)
            |> enrich_with_playtime(xuid, auth_header)

          Logger.info("[xbox] titlehub returned #{length(games)} games for xuid=#{xuid}")
          {:ok, games}

        {:ok, %{status: 401}} ->
          {:retry_unauthorized, xuid}

        {:ok, %{status: status, body: body}} ->
          Logger.error("[xbox] titlehub #{status} for xuid=#{xuid}: #{inspect(body)}")
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          Logger.error("[xbox] titlehub request failed: #{inspect(reason)}")
          {:error, reason}
      end
    end)
  end

  @impl true
  def fetch_achievements(%{external_user_id: xuid} = account, game_external_id) do
    title_id = to_title_id(game_external_id)

    with_auth(account, fn auth_header ->
      case Client.get_achievements(xuid, title_id, auth_header) do
        {:ok, %{status: 200, body: body}} ->
          achievements =
            body
            |> Map.get("achievements", [])
            |> List.wrap()
            |> Enum.map(&normalize_achievement/1)

          {:ok, achievements}

        {:ok, %{status: 401}} ->
          {:retry_unauthorized, xuid}

        {:ok, %{status: 429, headers: headers}} ->
          retry_after = retry_after_seconds(headers)
          Logger.warning("[xbox] 429 on title #{title_id}, sleeping #{retry_after}s")
          Process.sleep(retry_after * 1000)
          {:error, {:rate_limited, title_id}}

        {:ok, %{status: 404}} ->
          Logger.info("[xbox] no achievements service entry for title #{title_id} (404)")
          {:ok, []}

        {:ok, %{status: status, body: body}} ->
          Logger.warning("[xbox] achievements #{status} for title #{title_id}: #{inspect(body)}")
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          Logger.warning("[xbox] achievements request failed for title #{title_id}: #{inspect(reason)}")
          {:error, reason}
      end
    end)
  end

  defp with_auth(account, fun) do
    case Session.get_auth(account) do
      {:ok, %{auth_header: header}} ->
        case fun.(header) do
          {:retry_unauthorized, xuid} ->
            Session.invalidate(xuid)
            retry_after_invalidate(account, fun)

          other ->
            other
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp retry_after_invalidate(account, fun) do
    case Session.get_auth(account) do
      {:ok, %{auth_header: header}} ->
        case fun.(header) do
          {:retry_unauthorized, _xuid} -> {:error, :xbox_unauthorized}
          other -> other
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp to_title_id(id) when is_binary(id), do: id
  defp to_title_id(id) when is_integer(id), do: Integer.to_string(id)
  defp to_title_id(%{external_game_id: id}), do: to_title_id(id)
  defp to_title_id(%{"external_game_id" => id}), do: to_title_id(id)

  defp normalize_game(%{"titleId" => title_id} = raw) when not is_nil(title_id) do
    if game_title?(raw) do
      %{
        external_game_id: to_string(title_id),
        name: raw["name"],
        cover_image: raw["displayImage"],
        icon_image: raw["displayImage"],
        logo_image: nil,
        playtime_minutes: nil,
        last_played: parse_iso(get_in(raw, ["titleHistory", "lastTimePlayed"]))
      }
    else
      nil
    end
  end

  defp normalize_game(_), do: nil

  defp enrich_with_playtime(games, xuid, auth_header) do
    games
    |> Task.async_stream(
      fn game -> Map.put(game, :playtime_minutes, fetch_minutes_played(xuid, game.external_game_id, auth_header)) end,
      max_concurrency: 8,
      timeout: 15_000,
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, game} -> game
      {:exit, _} -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp fetch_minutes_played(xuid, title_id, auth_header) do
    case Client.get_title_stats(xuid, title_id, auth_header) do
      {:ok, %{status: 200, body: body}} ->
        body
        |> get_in(["statlistscollection", Access.at(0), "stats"])
        |> List.wrap()
        |> Enum.find_value(fn
          %{"name" => "MinutesPlayed", "value" => v} -> parse_minutes(v)
          _ -> nil
        end)

      {:ok, %{status: status}} when status in [400, 404] ->
        nil

      {:ok, %{status: status, body: body}} ->
        Logger.debug("[xbox] stats #{status} for title #{title_id}: #{inspect(body)}")
        nil

      {:error, reason} ->
        Logger.debug("[xbox] stats request failed for title #{title_id}: #{inspect(reason)}")
        nil
    end
  end

  defp parse_minutes(v) when is_integer(v), do: v

  defp parse_minutes(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      _ -> nil
    end
  end

  defp parse_minutes(_), do: nil

  defp game_title?(raw) do
    devices = raw["devices"] || []
    type = raw["type"]

    cond do
      type in ["Game", "DGame"] -> true
      type in ["App", "DApp"] -> false
      Enum.any?(devices, &(&1 in ["Xbox360", "XboxOne", "Scarlett", "XboxSeries"])) -> true
      true -> true
    end
  end

  defp normalize_achievement(raw) do
    unlock = raw |> get_in(["progression", "timeUnlocked"]) |> parse_iso()
    achieved = raw["progressState"] == "Achieved"

    %{
      external_achievement_id: to_string(raw["id"]),
      name: raw["name"],
      description: raw["description"] || raw["lockedDescription"],
      icon_image: pick_media_asset(raw["mediaAssets"]),
      icon_locked_image: nil,
      achieved: achieved,
      unlock_time: if(achieved, do: unlock, else: nil)
    }
  end

  defp pick_media_asset(assets) when is_list(assets) do
    icon =
      Enum.find_value(assets, fn
        %{"type" => "Icon", "url" => url} when is_binary(url) -> url
        _ -> nil
      end)

    icon || fallback_asset_url(assets)
  end

  defp pick_media_asset(_), do: nil

  defp fallback_asset_url([%{"url" => url} | _]) when is_binary(url), do: url
  defp fallback_asset_url(_), do: nil

  defp parse_iso(nil), do: nil
  defp parse_iso(@never_unlocked), do: nil

  defp parse_iso(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> DateTime.to_naive(dt)
      _ -> nil
    end
  end

  defp parse_iso(_), do: nil

  defp retry_after_seconds(headers) when is_list(headers) do
    headers
    |> Enum.find_value(fn
      {"retry-after", v} -> v
      {"Retry-After", v} -> v
      _ -> nil
    end)
    |> parse_retry_after()
  end

  defp retry_after_seconds(_), do: 5

  defp parse_retry_after(nil), do: 5
  defp parse_retry_after(v) when is_integer(v), do: max(v, 1)

  defp parse_retry_after(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> max(n, 1)
      _ -> 5
    end
  end

  defp parse_retry_after([v | _]), do: parse_retry_after(v)
  defp parse_retry_after(_), do: 5
end
