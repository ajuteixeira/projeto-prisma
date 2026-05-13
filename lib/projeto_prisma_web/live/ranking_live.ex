defmodule ProjetoPrismaWeb.RankingLive do
  use ProjetoPrismaWeb, :live_view

  alias ProjetoPrisma.Accounts

  @impl true
  def mount(_params, session, socket) do
    current_scope = Accounts.resolve_scope_from_session(session)
    profile = Accounts.get_profile_with_user(current_scope)

    players =
      case profile do
        %{id: profile_id} -> Accounts.ranking_for_profile(profile_id)
        _ -> []
      end

    socket =
      socket
      |> assign(:players, players)
      |> assign(:platform_filter, "all")
      |> assign(:search_term, "")

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_platform", %{"platform" => platform}, socket) do
    {:noreply, assign(socket, :platform_filter, platform)}
  end

  @impl true
  def handle_event("search", %{"value" => term}, socket) do
    {:noreply, assign(socket, :search_term, String.downcase(String.trim(term)))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <div class="max-w-7xl mx-auto">

        <div class="page-header">
          <h1 class="text-3xl font-bold text-white mb-2">Ranking Geral</h1>
          <p class="text-gray-400 text-sm">Competição entre você e as pessoas que você segue</p>
        </div>

        <div class="filter-section">
          <div class="flex flex-wrap items-center justify-between gap-4">
            <div class="flex items-center gap-2 flex-wrap">
              <span class="text-sm text-gray-400 filter-label">Filtros:</span>
              <div class="filter-buttons-group">
                <button
                  class={["filter-btn", @platform_filter == "all" && "active"]}
                  phx-click="filter_platform"
                  phx-value-platform="all"
                  aria-label="Todas"
                  title="Todas"
                >
                  <i class="fas fa-trophy"></i>
                </button>
                <button
                  class={["filter-btn", @platform_filter == "playstation" && "active"]}
                  phx-click="filter_platform"
                  phx-value-platform="playstation"
                  aria-label="PSN"
                  title="PSN"
                >
                  <i class="fab fa-playstation"></i>
                </button>
                <button
                  class={["filter-btn", @platform_filter == "xbox" && "active"]}
                  phx-click="filter_platform"
                  phx-value-platform="xbox"
                  aria-label="XBOX"
                  title="XBOX"
                >
                  <i class="fab fa-xbox"></i>
                </button>
                <button
                  class={["filter-btn", @platform_filter == "steam" && "active"]}
                  phx-click="filter_platform"
                  phx-value-platform="steam"
                  aria-label="Steam"
                  title="Steam"
                >
                  <i class="fab fa-steam"></i>
                </button>
                <button
                  class={["filter-btn", @platform_filter == "retroachievements" && "active"]}
                  phx-click="filter_platform"
                  phx-value-platform="retroachievements"
                  aria-label="RetroAchievements"
                  title="RetroAchievements"
                >
                  <i class="fas fa-gamepad"></i>
                </button>
              </div>
            </div>
            <div class="relative search-container">
              <i class="fas fa-search absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-500"></i>
              <input
                type="text"
                class="search-input"
                placeholder="Buscar jogador..."
                phx-keyup="search"
                phx-debounce="200"
                id="ranking-search"
              />
            </div>
          </div>
        </div>

        <div class="ranking-container">
          <h2 class="text-xl font-bold text-white mb-6">Top Jogadores</h2>

          <% filtered = filtered_players(@players, @platform_filter, @search_term) %>

          <%= if Enum.empty?(filtered) do %>
            <div class="text-gray-400 text-sm text-center py-8">
              Nenhum jogador encontrado.
            </div>
          <% else %>
            <table class="ranking-table">
              <thead class="ranking-header">
                <tr>
                  <th style="width: 80px">Posição</th>
                  <th>Jogador</th>
                  <th>Plataformas</th>
                  <th style="width: 140px; text-align: right">Conquistas</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={{entry, index} <- Enum.with_index(filtered, 1)}
                  class="ranking-row"
                  id={"ranking-row-#{entry.profile.id}"}
                >
                  <td>
                    <div class={position_badge_class(index)}>{index}º</div>
                  </td>
                  <td>
                    <div class="player-info">
                      <img
                        src={player_avatar(entry.profile)}
                        alt={player_username(entry.profile)}
                        class="player-avatar"
                      />
                      <div>
                        <span class={["player-name", entry.is_current_user && "text-blue-400"]}>
                          {player_username(entry.profile)}
                          <%= if entry.is_current_user do %>
                            <span class="text-xs text-gray-500 ml-1">(você)</span>
                          <% end %>
                        </span>
                        <div class="mobile-platforms">
                          <span :for={slug <- entry.platform_slugs} class={["platform-tag", platform_class(slug)]}>
                            <i class={platform_icon(slug)}></i>
                          </span>
                        </div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <span :for={slug <- entry.platform_slugs} class={["platform-tag", platform_class(slug)]}>
                      <i class={platform_icon(slug)}></i>
                      {platform_label(slug)}
                    </span>
                  </td>
                  <td style="text-align: right">
                    <span class="total-points">{entry.display_count}</span>
                  </td>
                  <td class="mobile-card-wrapper" style="display: none">
                    <div class="mobile-card">
                      <div class="mobile-top-row">
                        <div class={position_badge_class(index)}>{index}º</div>
                        <img
                          src={player_avatar(entry.profile)}
                          alt={player_username(entry.profile)}
                          class="player-avatar"
                        />
                        <div class="mobile-meta">
                          <div class={["player-name", entry.is_current_user && "text-blue-400"]}>
                            {player_username(entry.profile)}
                          </div>
                          <div class="mobile-platforms">
                            <span
                              :for={slug <- entry.platform_slugs}
                              class={["platform-tag", platform_class(slug)]}
                              aria-label={platform_label(slug)}
                            >
                              <i class={platform_icon(slug)}></i>
                            </span>
                          </div>
                        </div>
                      </div>
                      <div class="mobile-stats">
                        <div class="stat-box stat-total">
                          <div class="stat-label">Conquistas</div>
                          <div class="stat-value">{entry.display_count}</div>
                        </div>
                      </div>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          <% end %>

          <div class="mt-6 text-center">
            <p class="text-sm text-gray-500">
              <i class="fas fa-info-circle mr-2"></i>
              Ranking entre você e quem você segue
            </p>
          </div>
        </div>

      </div>
    </div>
    """
  end

  defp filtered_players(players, platform_filter, search_term) do
    players
    |> maybe_filter_platform(platform_filter)
    |> maybe_filter_search(search_term)
    |> add_display_counts(platform_filter)
    |> maybe_sort_by_platform(platform_filter)
  end

  defp add_display_counts(players, "all") do
    Enum.map(players, &Map.put(&1, :display_count, &1.achievement_count))
  end

  defp add_display_counts(players, platform) do
    Enum.map(players, fn entry ->
      Map.put(entry, :display_count, Map.get(entry.platform_counts, platform, 0))
    end)
  end

  defp maybe_sort_by_platform(players, "all"), do: players
  defp maybe_sort_by_platform(players, _), do: Enum.sort_by(players, & &1.display_count, :desc)

  defp maybe_filter_platform(players, "all"), do: players

  defp maybe_filter_platform(players, platform) do
    Enum.filter(players, fn entry ->
      Enum.any?(entry.platform_slugs, fn slug ->
        String.downcase(to_string(slug)) == String.downcase(platform)
      end)
    end)
  end

  defp maybe_filter_search(players, ""), do: players

  defp maybe_filter_search(players, term) do
    Enum.filter(players, fn entry ->
      username = entry.profile |> player_username() |> String.downcase()
      String.contains?(username, term)
    end)
  end

  defp position_badge_class(1), do: "position-badge position-1"
  defp position_badge_class(2), do: "position-badge position-2"
  defp position_badge_class(3), do: "position-badge position-3"
  defp position_badge_class(_), do: "position-badge position-other"

  defp platform_class("playstation"), do: "platform-psn"
  defp platform_class("steam"), do: "platform-steam"
  defp platform_class("xbox"), do: "platform-xbox"
  defp platform_class("retroachievements"), do: "platform-retro"
  defp platform_class(_), do: "platform-retro"

  defp platform_icon("playstation"), do: "fab fa-playstation"
  defp platform_icon("steam"), do: "fab fa-steam"
  defp platform_icon("xbox"), do: "fab fa-xbox"
  defp platform_icon("retroachievements"), do: "fas fa-gamepad"
  defp platform_icon(_), do: "fas fa-gamepad"

  defp platform_label("playstation"), do: "PSN"
  defp platform_label("steam"), do: "Steam"
  defp platform_label("xbox"), do: "Xbox"
  defp platform_label("retroachievements"), do: "Retro"
  defp platform_label(slug), do: String.upcase(to_string(slug))

  defp player_username(%{username: username}) when is_binary(username) and username != "",
    do: username

  defp player_username(%{user: %{username: username}}) when is_binary(username),
    do: username

  defp player_username(_), do: "jogador"

  defp player_avatar(%{avatar: %{data: data}} = profile) when is_binary(data) do
    data = String.trim(data)

    if data != "" and String.starts_with?(data, "data:image") do
      data
    else
      fallback_avatar(profile)
    end
  end

  defp player_avatar(profile), do: fallback_avatar(profile)

  defp fallback_avatar(profile) do
    seed = player_username(profile)
    "https://api.dicebear.com/7.x/avataaars/svg?seed=#{URI.encode(seed)}&backgroundColor=c0aede"
  end
end
