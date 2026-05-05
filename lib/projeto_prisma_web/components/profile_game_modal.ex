defmodule ProjetoPrismaWeb.ProfileGameModal do
  use ProjetoPrismaWeb, :html

  attr :game, :map, required: true
  attr :close_event, :string, default: "close_game_modal"

  def modal(assigns) do
    ~H"""
    <div
      id="profile-game-modal"
      class="fixed inset-0 z-50 flex items-center justify-center p-4"
      phx-window-keydown={@close_event}
      phx-key="escape"
    >
      <button
        type="button"
        phx-click={@close_event}
        class="absolute inset-0 bg-slate-950/80 backdrop-blur-sm"
        aria-label="Fechar detalhes do jogo"
      >
      </button>

      <div class="relative z-10 max-h-[90vh] w-full max-w-5xl overflow-hidden rounded-[30px] border border-gray-700 bg-[#0f172a] shadow-2xl">
        <div
          class="relative h-56 border-b border-gray-700 bg-cover bg-center"
          style={"background-image: linear-gradient(to bottom, rgba(15, 23, 42, 0.18), rgba(15, 23, 42, 0.96)), url('#{cover_image(@game)}');"}
        >
          <div class="absolute inset-0 bg-gradient-to-tr from-slate-950/80 via-transparent to-emerald-500/10">
          </div>

          <button
            type="button"
            phx-click={@close_event}
            class="absolute right-4 top-4 z-20 inline-flex items-center gap-2 rounded-full border border-white/15 bg-slate-900/80 px-4 py-2 text-sm text-white transition hover:border-white/30 hover:bg-slate-800/90"
          >
            <.icon name="hero-x-mark" class="size-4" />
            Fechar
          </button>

          <div class="absolute bottom-0 left-0 right-0 z-10 p-6 sm:p-8">
            <div class="flex flex-col gap-5 sm:flex-row sm:items-end">
              <img
                src={cover_image(@game)}
                alt={@game.game_name}
                class="h-28 w-28 rounded-2xl border border-white/10 object-cover shadow-xl"
              />

              <div class="min-w-0 flex-1">
                <h3 class="text-2xl font-black tracking-tight text-white sm:text-3xl">
                  {@game.game_name}
                </h3>
                <div class="mt-3 flex flex-wrap items-center gap-2 text-sm">
                  <span class="rounded-full border border-emerald-400/20 bg-emerald-400/10 px-3 py-1 text-emerald-100">
                    {@game.platform_name}
                  </span>
                  <span class="rounded-full border border-white/10 bg-white/5 px-3 py-1 text-gray-300">
                    {format_playtime(@game.playtime_minutes)} jogadas
                  </span>
                  <span class="rounded-full border border-white/10 bg-white/5 px-3 py-1 text-gray-300">
                    {completion_label(@game.completion_percent)} de conclusão
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="max-h-[calc(90vh-14rem)] p-6 sm:p-8">
          <div class="mt-6 grid gap-4 lg:grid-cols-2">
            <div class="rounded-3xl border border-gray-700 bg-slate-900/60 p-5">
              <h4 class="text-lg font-semibold text-white">Informações do Jogo</h4>
              <div class="mt-4 space-y-3 text-sm">
                <div class="flex items-start justify-between gap-4 border-b border-gray-800 pb-3">
                  <span class="text-gray-400">Nome</span>
                  <span class="text-right font-medium text-white">{@game.game_name}</span>
                </div>
                <div class="flex items-start justify-between gap-4 border-b border-gray-800 pb-3">
                  <span class="text-gray-400">Plataforma</span>
                  <span class="text-right font-medium text-white">
                    {@game.platform_name}
                  </span>
                </div>
                <div class="flex items-start justify-between gap-4 border-b border-gray-800 pb-3">
                  <span class="text-gray-400">Tempo de jogo</span>
                  <span class="text-right font-medium text-white">
                    {format_playtime(@game.playtime_minutes)}
                  </span>
                </div>
                <div class="flex items-start justify-between gap-4 border-b border-gray-800 pb-3">
                  <span class="text-gray-400">Última vez jogado</span>
                  <span class="text-right font-medium text-white">
                    {format_datetime(@game.last_played)}
                  </span>
                </div>
                <div class="flex items-start justify-between gap-4 border-b border-gray-800 pb-3">
                  <span class="text-gray-400">Último desbloqueio</span>
                  <span class="text-right font-medium text-white">
                    {format_datetime(@game.last_unlock_time)}
                  </span>
                </div>

              </div>
            </div>

            <div class="rounded-3xl border border-gray-700 bg-slate-900/60 p-5">
              <div class="flex items-center justify-between gap-4">
                <div>
                  <h4 class="text-lg font-semibold text-white">Conquistas</h4>
                  <p class="text-sm text-gray-400">
                    {unlocked_count(@game)} desbloqueadas de {total_count(@game)}
                  </p>
                </div>
                <div class="rounded-full border border-white/10 bg-white/5 px-3 py-1 text-xs uppercase tracking-[0.18em] text-gray-300">
                  {length(achievement_items(@game))} itens
                </div>
              </div>

              <div class="mt-4 max-h-80 space-y-3 overflow-y-auto pr-1">
                <div
                  :if={achievement_items(@game) == []}
                  class="rounded-2xl border border-dashed border-gray-700 px-4 py-6 text-center text-sm text-gray-400"
                >
                  Nenhuma conquista encontrada para este jogo.
                </div>

                <div
                  :for={achievement <- achievement_items(@game)}
                  class={[
                    "flex gap-4 rounded-2xl border p-3 transition",
                    achievement.achieved && "border-emerald-500/20 bg-emerald-500/10",
                    !achievement.achieved && "border-gray-700 bg-slate-950/60"
                  ]}
                >
                  <div class="h-14 w-14 shrink-0 overflow-hidden rounded-xl border border-white/10 bg-gray-800">
                    <img
                      :if={achievement_icon(achievement)}
                      src={achievement_icon(achievement)}
                      alt={achievement.name}
                      class="h-full w-full object-cover"
                    />
                    <div
                      :if={!achievement_icon(achievement)}
                      class="flex h-full w-full items-center justify-center text-gray-500"
                    >
                      <.icon name="hero-trophy" class="size-5" />
                    </div>
                  </div>

                  <div class="min-w-0 flex-1">
                    <div class="flex flex-wrap items-start justify-between gap-2">
                      <div>
                        <div class="font-semibold text-white">{achievement.name}</div>
                        <div :if={achievement.description} class="mt-1 text-sm text-gray-400">
                          {achievement.description}
                        </div>
                      </div>

                      <span
                        class={[
                          "rounded-full px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em]",
                          achievement.achieved && "bg-emerald-400/15 text-emerald-200",
                          !achievement.achieved && "bg-gray-800 text-gray-300"
                        ]}
                      >
                        {achievement_status_label(achievement)}
                      </span>
                    </div>

                    <div class="mt-2 text-xs text-gray-500">
                      {achievement_unlock_label(achievement)}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp cover_image(%{game_cover_image: img}) when is_binary(img) and img != "", do: img
  defp cover_image(%{game_icon_image: img}) when is_binary(img) and img != "", do: img
  defp cover_image(_), do: "https://placehold.co/96x96/1e293b/e2e8f0?text=Game"

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

  defp format_datetime(%NaiveDateTime{} = dt) do
    date = dt |> NaiveDateTime.to_date() |> Date.to_iso8601()
    time = dt |> NaiveDateTime.to_time() |> Time.to_iso8601()
    "#{date} #{time}"
  end

  defp format_datetime(_), do: "-"

  defp unlocked_count(%{unlocked_achievements: count}) when is_integer(count), do: count
  defp unlocked_count(_), do: 0

  defp total_count(%{total_achievements: count}) when is_integer(count), do: count
  defp total_count(_), do: 0

  defp completion_label(value) when is_float(value), do: "#{Float.round(value, 1)}%"
  defp completion_label(value) when is_integer(value), do: "#{value}%"
  defp completion_label(_), do: "0%"

  defp achievement_items(%{achievements: achievements}) when is_list(achievements), do: achievements
  defp achievement_items(_), do: []

  defp achievement_icon(%{achieved: true, icon_image: img}) when is_binary(img) and img != "", do: img

  defp achievement_icon(%{icon_locked_image: img}) when is_binary(img) and img != "",
    do: img

  defp achievement_icon(%{icon_image: img}) when is_binary(img) and img != "", do: img
  defp achievement_icon(_), do: nil

  defp achievement_status_label(%{achieved: true}), do: "Desbloqueada"
  defp achievement_status_label(_), do: "Bloqueada"

  defp achievement_unlock_label(%{achieved: true, unlock_time: %NaiveDateTime{} = unlock_time}) do
    "Obtida em #{format_datetime(unlock_time)}"
  end

  defp achievement_unlock_label(%{achieved: true}), do: "Conquista obtida"
  defp achievement_unlock_label(_), do: "Ainda não desbloqueada"
end
