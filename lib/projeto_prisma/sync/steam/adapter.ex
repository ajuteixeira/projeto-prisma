defmodule ProjetoPrisma.Sync.Steam.Adapter do
  @moduledoc """
  Adapter Steam que implementa o behaviour de integração de plataformas.

  Ele chama o `ProjetoPrisma.Sync.Steam.Client` para obter dados brutos e
  transforma as respostas no formato genérico definido pelo behaviour.
  """

  @behaviour ProjetoPrisma.Sync.PlatformBehaviour

  alias ProjetoPrisma.Sync.Steam.Client

  @impl true
  def fetch_games(%{external_user_id: steam_id, api_key: key}) do
    with {:ok, %{status: 200, body: body}} <- Client.get_owned_games(steam_id, key) do
      games =
        body["response"]["games"]
        |> Enum.map(&normalize_game/1)

      {:ok, games}
    else
      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def fetch_achievements(%{external_user_id: steam_id, api_key: key}, game_external_id) do
    with {:ok, %{status: 200, body: schema_body}} <-
           Client.get_schema_for_game(game_external_id, key),
         {:ok, %{status: 200, body: body}} <-
           Client.get_player_achievements(steam_id, game_external_id, key) do

      meta =
        schema_body["game"]["availableGameStats"]["achievements"]
        |> Enum.map(fn m -> {m["name"], m} end)
        |> Map.new()

      achievements =
        body["playerstats"]["achievements"]
        |> Enum.map(&normalize_achievement(&1, meta))

      {:ok, achievements}
    else
      {:ok, %{status: status, body: b}} ->
        {:error, {:http_error, status, b}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_game(raw) do
    %{
      external_game_id: to_string(raw["appid"]),
      name: raw["name"],
      cover_image: steam_cover_url(raw["appid"]),
      icon_image: nil,
      logo_image: nil,
      playtime_minutes: raw["playtime_forever"]
    }
  end

  defp normalize_achievement(raw, meta) do
    info = Map.get(meta, raw["apiname"], %{})

    %{
      external_achievement_id: raw["apiname"],
      name: info["displayName"] || raw["apiname"],
      description: info["description"],
      icon_image: info["icon"],
      icon_locked_image: info["icongray"],
      achieved: raw["achieved"] == 1,
      unlock_time: parse_unix(raw["unlocktime"])
    }
  end

  defp steam_cover_url(appid), do: "https://cdn.akamai.steamstatic.com/steam/apps/#{appid}/header.jpg"

  defp parse_unix(0), do: nil
  defp parse_unix(ts) when is_integer(ts) do
    DateTime.from_unix!(ts) |> DateTime.to_naive()
  end
end
