defmodule ProjetoPrisma.Sync.Steam.Client do
  @base_url "https://api.steampowered.com"

  def get_owned_games(steam_id, api_key) do
    Req.get("#{@base_url}/IPlayerService/GetOwnedGames/v1/",
      params: [
        key: api_key,
        steamid: steam_id,
        include_appinfo: true
      ]
    )
  end

  def get_player_achievements(steam_id, app_id, api_key) do
    Req.get("#{@base_url}/ISteamUserStats/GetPlayerAchievements/v1/",
      params: [
        key: api_key,
        steamid: steam_id,
        appid: app_id
      ]
    )
  end

  def get_player_summary(steam_id, api_key) do
    Req.get("#{@base_url}/ISteamUser/GetPlayerSummaries/v2/",
      params: [
        key: api_key,
        steamids: steam_id
      ]
    )
  end
end
