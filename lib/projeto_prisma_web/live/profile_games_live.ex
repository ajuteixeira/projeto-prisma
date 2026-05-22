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

    profile_id = profile && profile.id

    platforms =
      if is_integer(profile_id) do
        ProfileDashboard.list_profile_platforms(profile_id)
      else
        []
      end

    socket =
      socket
      |> assign(:profile_id, profile_id)
      |> assign(:current_page, 1)
      |> assign(:sort_by, :last_played)
      |> assign(:sort_order, :desc)
      |> assign(:search_query, "")
      |> assign(:search_form, to_form(%{"query" => ""}, as: :search))
      |> assign(:page_form, to_form(%{"page" => "1"}, as: :page_jump))
      |> assign(:platforms, platforms)
      |> assign(:platform_filter, nil)
      |> assign(:selected_game, nil)
      |> assign(:games_empty?, true)
      |> assign(:has_next_page?, false)
      |> assign(:has_previous_page?, false)
      |> assign(:total_games, 0)
      |> assign(:total_pages, 1)
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
    sort_order =
      case socket.assigns.sort_by do
        :last_played -> toggle_sort_order(socket.assigns.sort_order)
        _ -> :desc
      end

    socket =
      socket
      |> assign(:sort_by, :last_played)
      |> assign(:sort_order, sort_order)
      |> load_page(1)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_completion_order", _params, socket) do
    sort_order =
      case socket.assigns.sort_by do
        :completion -> toggle_sort_order(socket.assigns.sort_order)
        _ -> :desc
      end

    socket =
      socket
      |> assign(:sort_by, :completion)
      |> assign(:sort_order, sort_order)
      |> load_page(1)

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_platform", %{"platform_filter" => %{"platform_id" => raw}}, socket) do
    platform_id =
      case raw do
        "" -> nil
        value -> parse_integer(value)
      end

    {:noreply,
     socket
     |> assign(:platform_filter, platform_id)
     |> load_page(1)}
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
  def handle_event("go_to_page", %{"page_jump" => %{"page" => raw}}, socket) do
    socket =
      case parse_integer(raw) do
        nil ->
          assign(
            socket,
            :page_form,
            to_form(%{"page" => Integer.to_string(socket.assigns.current_page)}, as: :page_jump)
          )

        page ->
          load_page(socket, clamp_page(page, socket.assigns.total_pages))
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-gray-800/80 border border-gray-700 p-6 rounded-2xl w-full">
      <div class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <h2 class="text-2xl font-bold">Jogos</h2>

        <div class="flex w-full flex-1 flex-col gap-3 sm:flex-row sm:items-center">
          <.form
            for={@search_form}
            id="profile-games-search-form"
            phx-change="search_games"
            phx-submit="search_games"
            class="flex-1"
          >
            <input
              type="text"
              name={@search_form[:query].name}
              value={@search_form[:query].value}
              placeholder="Buscar jogo pelo nome"
              autocomplete="off"
              phx-debounce="300"
              aria-label="Buscar jogo pelo nome"
              class="w-full rounded-2xl border border-gray-700 bg-gray-900/80 px-4 py-3 text-sm text-white outline-none transition placeholder:text-gray-500 focus:border-emerald-400"
            />
          </.form>

          <.form
            :if={@platforms != []}
            for={%{}}
            as={:platform_filter}
            id="profile-games-platform-form"
            phx-change="filter_platform"
            class="w-full sm:w-auto"
          >
            <select
              name="platform_filter[platform_id]"
              aria-label="Filtrar por plataforma"
              class="w-full rounded-2xl border border-gray-700 bg-gray-900/80 px-4 py-3 text-sm text-white outline-none transition focus:border-emerald-400 sm:w-56"
            >
              <option value="" selected={is_nil(@platform_filter)}>Todas as plataformas</option>
              <option :for={p <- @platforms} value={p.id} selected={@platform_filter == p.id}>
                {p.name}
              </option>
            </select>
          </.form>
        </div>
      </div>

      <%!-- Cabeçalho desktop --%>
      <div class="hidden md:grid grid-cols-12 gap-4 px-4 py-3 border-b border-gray-700">
        <div class="col-span-3 table-header">Jogo</div>
        <div class="col-span-2 table-header">
          <button
            id="profile-games-sort-completion"
            type="button"
            phx-click="toggle_completion_order"
            class="inline-flex items-center gap-1 whitespace-nowrap text-left text-xs font-semibold uppercase tracking-wide text-gray-400 transition hover:text-white"
          >
            <span>Conclusão</span>
            <.icon
              :if={@sort_by == :completion}
              name={sort_icon_name(@sort_order)}
              class="size-4 shrink-0"
            />
          </button>
        </div>
        <div class="col-span-1 table-header">Conquistas</div>
        <div class="col-span-1 table-header">Tempo</div>
        <div class="col-span-2 table-header">Último Desbloqueio</div>
        <div class="col-span-2 table-header">
          <button
            id="profile-games-sort-last-played"
            type="button"
            phx-click="toggle_last_played_order"
            class="inline-flex items-center gap-1 whitespace-nowrap text-left text-xs font-semibold uppercase tracking-wide text-gray-400 transition hover:text-white"
          >
            <span>Última Vez Jogado</span>
            <.icon
              :if={@sort_by == :last_played}
              name={sort_icon_name(@sort_order)}
              class="size-4 shrink-0"
            />
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
            <p class="text-lg font-semibold text-white">
              {empty_state_title(@search_query, @platform_filter)}
            </p>
            <p class="mt-1 text-sm text-gray-400">
              {empty_state_message(@search_query, @platform_filter)}
            </p>
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
              <div class="col-span-6 md:col-span-1">
                <div class="text-sm">
                  <div>{format_playtime(game.playtime_minutes)}</div>
                </div>
              </div>
              <div class="col-span-6 md:col-span-2">
                <span class="text-sm text-gray-400">{format_datetime(game.last_unlock_time)}</span>
              </div>
              <div class="col-span-6 md:col-span-2">
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
        <div class="text-sm text-gray-400">
          Página <span class="font-semibold text-white">{@current_page}</span>
          de <span class="font-semibold text-white">{@total_pages}</span>
          <span class="mx-2 text-gray-600">·</span>
          <span class="font-semibold text-white">{@total_games}</span>
          {if @total_games == 1, do: "jogo", else: "jogos"}
        </div>

        <div class="flex flex-wrap items-center justify-end gap-2">
          <button
            id="profile-games-previous-page"
            type="button"
            phx-click="previous_page"
            disabled={!@has_previous_page?}
            class={[
              "inline-flex items-center gap-2 rounded-xl border px-4 py-2 text-sm font-medium transition",
              @has_previous_page? &&
                "border-gray-600 bg-gray-800/80 text-white hover:border-gray-500 hover:bg-gray-700/80",
              !@has_previous_page? &&
                "cursor-not-allowed border-gray-800 bg-gray-900/70 text-gray-500"
            ]}
          >
            <.icon name="hero-chevron-left" class="size-4" /> Anterior
          </button>

          <.form
            for={@page_form}
            id="profile-games-page-form"
            phx-submit="go_to_page"
            phx-change="go_to_page"
            class="flex items-center gap-2"
          >
            <input
              type="number"
              name="page_jump[page]"
              value={@page_form[:page].value}
              min="1"
              max={@total_pages}
              inputmode="numeric"
              phx-debounce="blur"
              aria-label="Ir para página"
              class="w-20 rounded-xl border border-gray-700 bg-gray-900/80 px-3 py-2 text-sm text-white outline-none transition placeholder:text-gray-500 focus:border-emerald-400"
            />
          </.form>

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
            Próxima <.icon name="hero-chevron-right" class="size-4" />
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
    sort_order = socket.assigns.sort_order
    sort_by = socket.assigns.sort_by
    search_query = socket.assigns.search_query
    platform_id = socket.assigns.platform_filter

    total_games =
      if is_integer(profile_id) do
        ProfileDashboard.count_games(profile_id,
          search_query: search_query,
          platform_id: platform_id
        )
      else
        0
      end

    total_pages = max(1, ceil_div(total_games, @page_size))
    current_page = clamp_page(page, total_pages)
    offset = (current_page - 1) * @page_size

    page_games =
      if is_integer(profile_id) and total_games > 0 do
        ProfileDashboard.list_games(profile_id, @page_size,
          offset: offset,
          sort_order: sort_order,
          sort_by: sort_by,
          search_query: search_query,
          platform_id: platform_id
        )
      else
        []
      end

    socket
    |> assign(:current_page, current_page)
    |> assign(:selected_game, nil)
    |> assign(:games_empty?, page_games == [])
    |> assign(:has_next_page?, current_page < total_pages and total_games > 0)
    |> assign(:has_previous_page?, current_page > 1)
    |> assign(:total_games, total_games)
    |> assign(:total_pages, total_pages)
    |> assign(
      :page_form,
      to_form(%{"page" => Integer.to_string(current_page)}, as: :page_jump)
    )
    |> stream(:games, page_games, reset: true)
  end

  defp clamp_page(page, total_pages) when is_integer(page) and is_integer(total_pages) do
    page |> max(1) |> min(max(total_pages, 1))
  end

  defp ceil_div(_numerator, denominator) when denominator <= 0, do: 0
  defp ceil_div(numerator, _denominator) when numerator <= 0, do: 0
  defp ceil_div(numerator, denominator), do: div(numerator + denominator - 1, denominator)

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(_sort_order), do: :asc

  defp sort_icon_name(:asc), do: "hero-chevron-up"
  defp sort_icon_name(_sort_order), do: "hero-chevron-down"

  defp empty_state_title("", nil), do: "Sem jogos sincronizados"
  defp empty_state_title(_search_query, _platform_filter), do: "Nenhum jogo encontrado"

  defp empty_state_message("", nil),
    do: "Conecte uma plataforma para começar a preencher seu histórico de jogos."

  defp empty_state_message(_search_query, platform_filter) when not is_nil(platform_filter),
    do: "Nenhum jogo encontrado para os filtros aplicados."

  defp empty_state_message(_search_query, _platform_filter),
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
