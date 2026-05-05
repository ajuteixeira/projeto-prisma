defmodule ProjetoPrismaWeb.ProfileGamesLive do
  use ProjetoPrismaWeb, :live_view

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.ProfileDashboard
  alias ProjetoPrisma.Accounts.Scope

  @page_size 10

  @impl true
  def mount(_params, session, socket) do
    current_scope = Accounts.resolve_scope_from_session(session)
    profile = ProfileDashboard.profile_for_user(scope_user_id(current_scope))

    socket =
      socket
      |> assign(:profile_id, profile && profile.id)
      |> assign(:current_page, 1)
      |> assign(:sort_order, :desc)
      |> assign(:search_query, "")
      |> assign(:search_form, to_form(%{"query" => ""}, as: :search))
      |> assign(:selected_game, nil)
      |> assign(:games_empty?, true)
      |> assign(:has_next_page?, false)
      |> assign(:has_previous_page?, false)
      |> stream_configure(:games, dom_id: &"profile-game-#{&1.profile_game_id}")
      |> stream(:games, [], reset: true)
      |> load_page(1)

    {:ok, socket}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    socket =
      if socket.assigns.has_next_page? do
        load_page(socket, socket.assigns.current_page + 1)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("previous_page", _params, socket) do
    socket =
      if socket.assigns.has_previous_page? do
        load_page(socket, socket.assigns.current_page - 1)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_last_played_order", _params, socket) do
    socket =
      socket
      |> assign(:sort_order, toggle_sort_order(socket.assigns.sort_order))
      |> load_page(1)

    {:noreply, socket}
  end

  @impl true
  def handle_event("search_games", %{"search" => search_params}, socket) do
    query = normalize_search_query(search_params["query"])

    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:search_form, to_form(%{"query" => query}, as: :search))
      |> load_page(1)

    {:noreply, socket}
  end

  @impl true
  def handle_event("open_game_modal", %{"profile-game-id" => profile_game_id}, socket) do
    game =
      with profile_id when is_integer(profile_id) <- socket.assigns.profile_id,
           game_id when is_integer(game_id) <- parse_integer(profile_game_id) do
        ProfileDashboard.game_details(profile_id, game_id)
      else
        _ -> nil
      end

    {:noreply, assign(socket, :selected_game, game)}
  end

  @impl true
  def handle_event("close_game_modal", _params, socket) do
    {:noreply, assign(socket, :selected_game, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-gray-800/80 border border-gray-700 p-6 rounded-2xl w-full">
      <div class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <h2 class="text-2xl font-bold">Jogos</h2>

        <.form
          for={@search_form}
          id="profile-games-search-form"
          phx-change="search_games"
          phx-submit="search_games"
          class="w-full lg:max-w-sm"
        >
          <.input
            field={@search_form[:query]}
            type="text"
            placeholder="Buscar jogo pelo nome"
            autocomplete="off"
            phx-debounce="300"
            aria-label="Buscar jogo pelo nome"
            class="w-full rounded-2xl border border-gray-700 bg-gray-900/80 px-4 py-3 text-sm text-white outline-none transition placeholder:text-gray-500 focus:border-emerald-400"
          />
        </.form>
      </div>

      <%!-- Cabeçalho desktop --%>
      <div class="hidden md:grid grid-cols-12 gap-4 px-4 py-3 border-b border-gray-700">
        <div class="col-span-3 table-header">Jogo</div>
        <div class="col-span-2 table-header">Conclusão</div>
        <div class="col-span-1 table-header">Conquistas</div>
        <div class="col-span-2 table-header">Tempo de Jogo</div>
        <div class="col-span-2 table-header">Último Desbloqueio</div>
        <div class="col-span-1 table-header">
          <button
            id="profile-games-sort-last-played"
            type="button"
            phx-click="toggle_last_played_order"
            class="inline-flex items-center gap-1 text-left transition hover:text-white"
          >
            <span>Última Vez Jogado</span>
            <.icon name={sort_icon_name(@sort_order)} class="size-4" />
          </button>
        </div>
        <div class="col-span-1 table-header">Plataforma</div>
      </div>

      <div
        :if={@games_empty?}
        id="profile-games-empty"
        class="mt-2 rounded-2xl border border-dashed border-gray-700 bg-gray-900/40 px-5 py-10 text-center"
      >
        <div class="mx-auto flex max-w-md flex-col items-center gap-3">
          <div class="rounded-full border border-emerald-500/30 bg-emerald-500/10 p-3">
            <.icon name="hero-information-circle" class="size-6 text-emerald-300" />
          </div>
          <div>
            <p class="text-lg font-semibold text-white">{empty_state_title(@search_query)}</p>
            <p class="mt-1 text-sm text-gray-400">{empty_state_message(@search_query)}</p>
          </div>
        </div>
      </div>

      <div id="profile-games-list" class="space-y-2 mt-2" phx-update="stream">
        <div :for={{dom_id, game} <- @streams.games} id={dom_id}>
          <button
            id={"profile-games-open-#{game.profile_game_id}"}
            type="button"
            phx-click="open_game_modal"
            phx-value-profile-game-id={game.profile_game_id}
            class="block w-full text-left"
          >
            <%!-- Card mobile --%>
            <div class="mobile-game-card mb-2 rounded-lg bg-transparent p-3 transition hover:bg-gray-700/20 md:hidden">
              <div class="mobile-top-row flex items-center gap-3">
                <img
                  src={cover_image(game)}
                  alt={game.game_name}
                  class="h-12 w-12 rounded object-cover"
                />
                <div class="mobile-meta flex-1">
                  <div class="flex items-center justify-between gap-3">
                    <div class="mobile-title font-semibold text-base">{game.game_name}</div>
                    <div class="mobile-trophies flex items-center gap-2 text-sm">
                      <.icon name="hero-trophy" class="size-4 text-yellow-400" />
                      <span class="font-semibold">
                        {game.unlocked_achievements} / {game.total_achievements}
                      </span>
                    </div>
                  </div>
                  <div class="mt-2">
                    <div class="progress-bar h-2 overflow-hidden rounded-full bg-gray-700">
                      <div
                        class="progress-fill bg-emerald-500"
                        style={"width: #{game.completion_percent}%;"}
                      >
                      </div>
                    </div>
                    <div class="mt-1 flex items-center justify-between text-xs text-gray-400">
                      <span>{game.completion_percent}%</span>
                      <span>{format_date(game.last_played)}</span>
                    </div>
                  </div>
                </div>
              </div>
              <div class="mobile-meta-extra mt-2 flex items-center justify-between gap-3 text-xs text-gray-400">
                <div>
                  <div class="font-semibold">{format_playtime(game.playtime_minutes)}</div>
                  <div class="text-xs text-gray-500">
                    Total {format_playtime(game.playtime_minutes)}
                  </div>
                </div>
                <div class="flex items-center gap-2">
                  <span class="platform-badge inline-block rounded bg-blue-700/30 px-3 py-1 text-xs">
                    {game.platform_name}
                  </span>
                  <.icon name="hero-chevron-right" class="size-4 text-gray-500" />
                </div>
              </div>
            </div>

            <%!-- Linha desktop --%>
            <div class="game-row hidden items-center gap-4 rounded-lg p-4 transition hover:bg-gray-700/20 md:grid md:grid-cols-12">
              <div class="col-span-12 flex items-center space-x-3 md:col-span-3">
                <img src={cover_image(game)} alt={game.game_name} class="game-thumbnail" />
                <div>
                  <div class="font-semibold">{game.game_name}</div>
                  <div class="mt-1 flex items-center gap-1 text-xs text-gray-500">
                    <span>Ver detalhes</span>
                    <.icon name="hero-chevron-right" class="size-3" />
                  </div>
                </div>
              </div>
              <div class="col-span-6 md:col-span-2">
                <div class="progress-bar bg-gray-700">
                  <div
                    class="progress-fill bg-gradient-to-r from-green-500 to-emerald-600"
                    style={"width: #{game.completion_percent}%;"}
                  >
                  </div>
                </div>
                <span class="mt-1 block text-xs text-gray-400">{game.completion_percent}%</span>
              </div>
              <div class="col-span-6 md:col-span-1">
                <span class="text-sm">
                  <.icon name="hero-trophy" class="mr-1 inline-block size-4 text-yellow-500" />
                  {game.unlocked_achievements} / {game.total_achievements}
                </span>
              </div>
              <div class="col-span-6 md:col-span-2">
                <div class="text-sm">
                  <div>{format_playtime(game.playtime_minutes)}</div>
                  <div class="text-xs text-gray-400">
                    Total {format_playtime(game.playtime_minutes)}
                  </div>
                </div>
              </div>
              <div class="col-span-6 md:col-span-2">
                <span class="text-sm text-gray-400">{format_datetime(game.last_unlock_time)}</span>
              </div>
              <div class="col-span-6 md:col-span-1">
                <span class="text-sm text-gray-400">{format_date(game.last_played)}</span>
              </div>
              <div class="col-span-6 md:col-span-1">
                <span class="platform-badge">{game.platform_name}</span>
              </div>
            </div>
          </button>
        </div>
      </div>

      <div
        :if={!@games_empty?}
        id="profile-games-pagination"
        class="mt-6 flex flex-col gap-3 border-t border-gray-700/80 pt-5 sm:flex-row sm:items-center sm:justify-between"
      >
        <div class="flex items-center justify-end gap-2">
          <button
            id="profile-games-previous-page"
            type="button"
            phx-click="previous_page"
            disabled={!@has_previous_page?}
            class={[
              "inline-flex items-center gap-2 rounded-xl border px-4 py-2 text-sm font-medium transition",
              @has_previous_page? &&
                "border-gray-600 bg-gray-800/80 text-white hover:border-gray-500 hover:bg-gray-700/80",
              !@has_previous_page? && "cursor-not-allowed border-gray-800 bg-gray-900/70 text-gray-500"
            ]}
          >
            <.icon name="hero-chevron-left" class="size-4" />
            Anterior
          </button>

          <button
            id="profile-games-next-page"
            type="button"
            phx-click="next_page"
            disabled={!@has_next_page?}
            class={[
              "inline-flex items-center gap-2 rounded-xl border px-4 py-2 text-sm font-medium transition",
              @has_next_page? &&
                "border-emerald-500/40 bg-emerald-500/10 text-emerald-100 hover:border-emerald-400/70 hover:bg-emerald-500/15",
              !@has_next_page? &&
                "cursor-not-allowed border-gray-800 bg-gray-900/70 text-gray-500"
            ]}
          >
            Próxima
            <.icon name="hero-chevron-right" class="size-4" />
          </button>
        </div>
      </div>

      <ProjetoPrismaWeb.ProfileGameModal.modal
        :if={@selected_game}
        game={@selected_game}
        close_event="close_game_modal"
      />
    </div>
    """
  end

  # ── helpers ──────────────────────────────────────────────────────────────────

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

  defp format_date(%NaiveDateTime{} = dt),
    do: dt |> NaiveDateTime.to_date() |> Date.to_iso8601()

  defp format_date(_), do: "-"

  defp load_page(socket, page) when page > 0 do
    profile_id = socket.assigns.profile_id
    offset = (page - 1) * @page_size
    sort_order = socket.assigns.sort_order
    search_query = socket.assigns.search_query

    games =
      if is_integer(profile_id) do
        ProfileDashboard.list_games(profile_id, @page_size + 1,
          offset: offset,
          sort_order: sort_order,
          search_query: search_query
        )
      else
        []
      end

    {page_games, has_next_page?} = page_entries(games)

    if page > 1 and page_games == [] do
      load_page(socket, page - 1)
    else
      socket
      |> assign(:current_page, page)
      |> assign(:selected_game, nil)
      |> assign(:games_empty?, page_games == [])
      |> assign(:has_next_page?, has_next_page?)
      |> assign(:has_previous_page?, page > 1)
      |> stream(:games, page_games, reset: true)
    end
  end

  defp page_entries(games) do
    case Enum.split(games, @page_size) do
      {page_games, []} -> {page_games, false}
      {page_games, _rest} -> {page_games, true}
    end
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(_sort_order), do: :asc

  defp sort_icon_name(:asc), do: "hero-chevron-up"
  defp sort_icon_name(_sort_order), do: "hero-chevron-down"

  defp empty_state_title(""), do: "Sem jogos sincronizados"
  defp empty_state_title(_search_query), do: "Nenhum jogo encontrado"

  defp empty_state_message(""),
    do: "Conecte uma plataforma para começar a preencher seu histórico de jogos."

  defp empty_state_message(_search_query),
    do: "Tente outro nome para localizar um jogo específico na sua biblioteca."

  defp normalize_search_query(search_query) when is_binary(search_query) do
    search_query
    |> String.trim()
  end

  defp normalize_search_query(_search_query), do: ""

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp parse_integer(_value), do: nil

  defp scope_user_id(%Scope{user: %{id: id}}) when is_integer(id), do: id
  defp scope_user_id(_), do: nil
end
