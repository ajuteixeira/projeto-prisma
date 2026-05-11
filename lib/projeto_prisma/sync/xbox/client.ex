defmodule ProjetoPrisma.Sync.Xbox.Client do
  @moduledoc """
  Cliente HTTP bruto para Xbox Live (titlehub + achievements).

  Recebe `auth_header` já montado por `ProjetoPrisma.Sync.Xbox.Session`.
  """

  @titlehub_url "https://titlehub.xboxlive.com"
  @achievements_url "https://achievements.xboxlive.com"
  @userstats_url "https://userstats.xboxlive.com"

  def get_titles(xuid, auth_header) when is_binary(xuid) and is_binary(auth_header) do
    Req.get(
      "#{@titlehub_url}/users/xuid(#{xuid})/titles/titleHistory/decoration/Achievement,Stats",
      headers: titlehub_headers(auth_header)
    )
  end

  def get_achievements(xuid, title_id, auth_header)
      when is_binary(xuid) and is_binary(auth_header) do
    Req.get(
      "#{@achievements_url}/users/xuid(#{xuid})/achievements",
      params: [titleId: to_string(title_id), maxItems: 1000],
      headers: achievements_headers(auth_header)
    )
  end

  def get_title_stats(xuid, title_id, auth_header)
      when is_binary(xuid) and is_binary(auth_header) do
    Req.get(
      "#{@userstats_url}/users/xuid(#{xuid})/titles/#{title_id}/stats",
      params: [stats: "MinutesPlayed"],
      headers: [
        {"Authorization", auth_header},
        {"x-xbl-contract-version", "2"},
        {"Accept", "application/json"}
      ]
    )
  end

  defp titlehub_headers(auth_header) do
    [
      {"Authorization", auth_header},
      {"x-xbl-contract-version", "2"},
      {"Accept", "application/json"},
      {"Accept-Language", "en-US"}
    ]
  end

  defp achievements_headers(auth_header) do
    [
      {"Authorization", auth_header},
      {"x-xbl-contract-version", "2"},
      {"Accept", "application/json"}
    ]
  end
end
