# defmodule ProjetoPrisma.Sync.Psn.Adapter do

#   @behaviour ProjetoPrisma.Sync.PlatformBehaviour

#   alias ProjetoPrisma.Sync.Psn.Client

#   @impl true
#   def fetch_games(%{external_user_id: psn_id, api_key: access_token}) do
#     with {:ok, %{status: 200, body: body}} <- Client.get_owned_games(psn_id, access_token) do
#       games =
#         body["titles"]
#         |> Enum.map(&normalize_game/1)
#       {:ok, games}
#     else
#       {:ok, %{status: status, body: body}} ->
#         {:error, {:http_error, status, body}}
#       {:error, reason} ->
#         {:error, reason}
#     end
#   end

#   @impl true
#   def fetch_achievements(%{external_user_id: psn_id, api_key: access_token}, game_external_id) do
#     {:ok, []}
#   end

#   defp normalize_game(raw) do
#     %{
#       external_game_id: to_string(raw["titleId"]),
#       name: raw["name"],
#       cover_image: nil,
#       icon_image: nil,
#       logo_image: nil,
#       playtime_minutes: raw["playDuration"]
#     }
#   end

# end
