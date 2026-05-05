defmodule ProjetoPrismaWeb.ProfileRecentlyPlayedLive do
  use ProjetoPrismaWeb, :live_view

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.ProfileDashboard
  alias ProjetoPrisma.Accounts.Scope

  @impl true
  def mount(_params, session, socket) do
    current_scope = Accounts.resolve_scope_from_session(session)
    profile = ProfileDashboard.profile_for_user(scope_user_id(current_scope))
    game = if profile, do: ProfileDashboard.recently_played(profile.id), else: nil

    {:ok, assign(socket, :game, game)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Hero image com gradiente --%>
    <div class="rounded-2xl border border-gray-700 overflow-hidden">
      <div
        class="relative h-48"
        style={"background: linear-gradient(to bottom, rgba(15, 20, 25, 0.3), rgba(15, 20, 25, 0.95)), url('#{hero_image(@game)}') center/cover;"}
      >
        <div class="absolute bottom-0 left-0 right-0 p-6">
          <div class="flex items-start space-x-4">
            <img
              src={thumb_image(@game)}
              alt={game_name(@game)}
              class="w-20 h-20 rounded border-2 border-gray-700 shadow-lg object-cover"
            />
            <div class="flex-1">
              <h3 class="text-xl font-bold mb-2">{game_name(@game)}</h3>
              <div class="text-sm text-gray-300 mb-3">
                <span class="font-semibold">{format_playtime(playtime(@game))} registradas</span>
              </div>
              <div class="text-xs text-gray-400">
                jogado pela última vez em {format_date(last_played(@game))}
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Barra de conquistas --%>
      <div class="bg-gray-800/80 px-6 py-3 border-t border-gray-700/50">
        <div class="flex items-center justify-between mb-2">
          <span class="text-xs text-gray-400 font-medium uppercase tracking-wider">Conquistas</span>
          <span class="text-xs text-gray-400">{unlocked_count(@game)} de {total_count(@game)}</span>
        </div>

        <div class="flex items-center space-x-2 mb-2">
          <div class="flex-1 h-1.5 bg-gray-700 rounded-full overflow-hidden">
            <div
              class="h-full bg-gradient-to-r from-blue-500 to-blue-600 rounded-full"
              style={"width: #{completion_percent(@game)}%;"}
            >
            </div>
          </div>
        </div>

        <div class="flex items-center space-x-1">
          <div
            :for={achievement <- preview_achievements(@game)}
            class="w-10 h-10 bg-gray-700 rounded flex items-center justify-center text-lg overflow-hidden"
            title={achievement.name || "Conquista"}
          >
            <img
              :if={is_binary(achievement.icon) and achievement.icon != ""}
              src={achievement.icon}
              alt={achievement.name || "Conquista"}
              class="w-full h-full object-cover"
            />
            <span :if={not is_binary(achievement.icon) or achievement.icon == ""}>🏆</span>
          </div>

          <div class="flex items-center justify-center text-sm text-gray-400 font-semibold ml-2">
            +{remaining_count(@game)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── helpers ──────────────────────────────────────────────────────────────────

  defp game_name(%{game_name: name}) when is_binary(name) and name != "", do: name
  defp game_name(_), do: "Nenhum jogo recente"

  defp playtime(%{playtime_minutes: v}) when is_integer(v), do: v
  defp playtime(_), do: 0

  defp last_played(%{last_played: v}), do: v
  defp last_played(_), do: nil

  defp unlocked_count(%{unlocked_achievements: v}) when is_integer(v), do: v
  defp unlocked_count(_), do: 0

  defp total_count(%{total_achievements: v}) when is_integer(v), do: v
  defp total_count(_), do: 0

  defp completion_percent(%{completion_percent: v}) when is_number(v), do: v
  defp completion_percent(_), do: 0

  defp preview_achievements(%{recent_achievements: [_ | _] = list}), do: Enum.take(list, 5)
  defp preview_achievements(_), do: List.duplicate(%{name: "Conquista", icon: nil}, 5)

  defp remaining_count(%{total_achievements: total}) when is_integer(total) and total > 5,
    do: total - 5

  defp remaining_count(_), do: 0

  defp hero_image(%{game_cover_image: img}) when is_binary(img) and img != "", do: img
  defp hero_image(%{game_icon_image: img}) when is_binary(img) and img != "", do: img
  defp hero_image(_), do: "https://placehold.co/1200x360/0f172a/94a3b8?text=Sem+capa"

  defp thumb_image(%{game_icon_image: img}) when is_binary(img) and img != "", do: img
  defp thumb_image(%{game_cover_image: img}) when is_binary(img) and img != "", do: img
  defp thumb_image(_), do: "https://placehold.co/184x69/1e293b/e2e8f0?text=Game"

  defp format_playtime(minutes) when is_integer(minutes) and minutes >= 0 do
    hours = div(minutes, 60)
    mins = rem(minutes, 60)

    cond do
      hours > 0 and mins > 0 -> "#{hours}h #{mins}m"
      hours > 0 -> "#{hours}h"
      true -> "#{mins}m"
    end
  end

  defp format_playtime(_), do: "0h"

  defp format_date(%NaiveDateTime{} = dt),
    do: dt |> NaiveDateTime.to_date() |> Date.to_iso8601()

  defp format_date(_), do: "data desconhecida"

  defp scope_user_id(%Scope{user: %{id: id}}) when is_integer(id), do: id
  defp scope_user_id(_), do: nil
end
