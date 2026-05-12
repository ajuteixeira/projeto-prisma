defmodule ProjetoPrismaWeb.FollowersLive do
  use ProjetoPrismaWeb, :live_view

  alias ProjetoPrisma.Accounts

  @impl true
  def mount(_params, session, socket) do
    current_scope = Accounts.resolve_scope_from_session(session)
    profile = Accounts.get_profile_with_user(current_scope)

    socket =
      socket
      |> assign(:current_scope, current_scope)
      |> assign(:profile, profile)
      |> assign(:active_tab, "seguidores")
      |> assign(:followers, [])
      |> assign(:following, [])
      |> assign(:following_ids, MapSet.new())
      |> assign(:followers_count, 0)
      |> assign(:following_count, 0)
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:search_form, to_form(%{"query" => ""}, as: :search))
      |> load_follow_data()

    {:ok, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("toggle_follow", %{"profile-id" => raw_id}, socket) do
    profile = socket.assigns.profile

    with %{id: follower_id} when is_integer(follower_id) <- profile,
         {followed_id, ""} <- Integer.parse(to_string(raw_id)) do
      socket =
        case Accounts.toggle_follow(follower_id, followed_id) do
          {:ok, _state} ->
            socket
            |> load_follow_data()
            |> refresh_search_results()

          {:error, :cannot_follow_self} ->
            put_flash(socket, :error, "Voce nao pode seguir seu proprio perfil.")

          {:error, _reason} ->
            put_flash(socket, :error, "Nao foi possivel atualizar o follow agora.")
        end

      {:noreply, socket}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Perfil invalido para seguir.")}
    end
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:search_form, to_form(%{"query" => query}, as: :search))
      |> refresh_search_results()

    {:noreply, socket}
  end

  def handle_event("search", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="followers-page" id="followers-page">
      <div class="followers-header">
        <i class="fas fa-users" aria-hidden="true"></i>
        <h1>{header_title(@active_tab, @followers_count, @following_count)}</h1>
      </div>

      <div class="followers-tabs">
        <button
          type="button"
          class={tab_class(@active_tab, "seguidores")}
          phx-click="switch_tab"
          phx-value-tab="seguidores"
          id="followers-tab-seguidores"
        >
          Seguidores
        </button>
        <button
          type="button"
          class={tab_class(@active_tab, "seguindo")}
          phx-click="switch_tab"
          phx-value-tab="seguindo"
          id="followers-tab-seguindo"
        >
          Seguindo
        </button>
        <button
          type="button"
          class={tab_class(@active_tab, "pesquisar")}
          phx-click="switch_tab"
          phx-value-tab="pesquisar"
          id="followers-tab-pesquisar"
        >
          Pesquisar
        </button>
      </div>

      <div class={tab_content_class(@active_tab, "seguidores")} id="seguidores">
        <div class="followers-grid" id="followers-list">
          <%= if Enum.empty?(@followers) do %>
            <div class="text-gray-400 text-sm">Nenhum seguidor ainda.</div>
          <% else %>
            <div :for={follower <- @followers} class="follower-card" id={"follower-#{follower.id}"}>
              <img
                src={profile_avatar(follower)}
                alt={profile_display_name(follower)}
                class="follower-avatar"
              />
              <div class="follower-name">{profile_display_name(follower)}</div>
              <div class="follower-username">@{profile_username(follower)}</div>
              <button
                type="button"
                class={follow_button_class(@following_ids, follower.id)}
                phx-click="toggle_follow"
                phx-value-profile-id={follower.id}
                aria-label={follow_button_label(@following_ids, follower.id)}
              >
                {follow_button_text(@following_ids, follower.id)}
              </button>
            </div>
          <% end %>
        </div>
      </div>

      <div class={tab_content_class(@active_tab, "seguindo")} id="seguindo">
        <div class="followers-grid" id="following-list">
          <%= if Enum.empty?(@following) do %>
            <div class="text-gray-400 text-sm">Voce ainda nao segue ninguem.</div>
          <% else %>
            <div :for={profile <- @following} class="follower-card" id={"following-#{profile.id}"}>
              <img
                src={profile_avatar(profile)}
                alt={profile_display_name(profile)}
                class="follower-avatar"
              />
              <div class="follower-name">{profile_display_name(profile)}</div>
              <div class="follower-username">@{profile_username(profile)}</div>
              <button
                type="button"
                class={follow_button_class(@following_ids, profile.id)}
                phx-click="toggle_follow"
                phx-value-profile-id={profile.id}
                aria-label={follow_button_label(@following_ids, profile.id)}
              >
                {follow_button_text(@following_ids, profile.id)}
              </button>
            </div>
          <% end %>
        </div>
      </div>

      <div class={tab_content_class(@active_tab, "pesquisar")} id="pesquisar">
        <div class="search-box">
          <.form for={@search_form} id="followers-search-form" phx-change="search">
            <.input
              field={@search_form[:query]}
              type="text"
              placeholder="Buscar por username"
              autocomplete="off"
              phx-debounce="300"
              class="search-input"
              aria-label="Buscar por username"
            />
          </.form>
        </div>

        <div class="followers-grid" id="followers-search-results">
          <%= if @search_query != "" and Enum.empty?(@search_results) do %>
            <div class="text-gray-400 text-sm">Nenhum resultado encontrado.</div>
          <% end %>

          <div :for={profile <- @search_results} class="follower-card" id={"search-#{profile.id}"}>
            <img
              src={profile_avatar(profile)}
              alt={profile_display_name(profile)}
              class="follower-avatar"
            />
            <div class="follower-name">{profile_display_name(profile)}</div>
            <div class="follower-username">@{profile_username(profile)}</div>
            <button
              type="button"
              class={follow_button_class(@following_ids, profile.id)}
              phx-click="toggle_follow"
              phx-value-profile-id={profile.id}
              aria-label={follow_button_label(@following_ids, profile.id)}
            >
              {follow_button_text(@following_ids, profile.id)}
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp load_follow_data(socket) do
    case socket.assigns.profile do
      %{id: profile_id} ->
        followers = Accounts.list_followers(profile_id)
        following = Accounts.list_following(profile_id)
        following_ids = MapSet.new(Accounts.list_following_ids(profile_id))
        followers_count = Accounts.count_profile_followers(profile_id)
        following_count = Accounts.count_profile_following(profile_id)

        socket
        |> assign(:followers, followers)
        |> assign(:following, following)
        |> assign(:following_ids, following_ids)
        |> assign(:followers_count, followers_count)
        |> assign(:following_count, following_count)

      _ ->
        socket
    end
  end

  defp refresh_search_results(socket) do
    case socket.assigns.profile do
      %{id: profile_id} ->
        results = Accounts.search_profiles_by_username(profile_id, socket.assigns.search_query)
        assign(socket, :search_results, results)

      _ ->
        socket
    end
  end

  defp header_title("seguidores", followers_count, _following_count),
    do: "Seguidores (#{followers_count})"

  defp header_title("seguindo", _followers_count, following_count),
    do: "Seguindo (#{following_count})"

  defp header_title(_tab, _followers_count, _following_count),
    do: "Pesquisar Pessoas"

  defp tab_class(active_tab, tab) do
    ["followers-tab", active_tab == tab && "active"]
  end

  defp tab_content_class(active_tab, tab) do
    ["tab-content", active_tab == tab && "active"]
  end

  defp follow_button_class(following_ids, profile_id) do
    is_following = MapSet.member?(following_ids, profile_id)
    ["btn-follow", is_following && "following"]
  end

  defp follow_button_label(following_ids, profile_id) do
    if MapSet.member?(following_ids, profile_id) do
      "Deixar de seguir"
    else
      "Seguir"
    end
  end

  defp follow_button_text(following_ids, profile_id) do
    if MapSet.member?(following_ids, profile_id) do
      ""
    else
      "Seguir"
    end
  end

  defp profile_username(%{username: username}) when is_binary(username), do: String.trim(username)
  defp profile_username(_profile), do: "usuario"

  defp profile_display_name(nil), do: "usuario"

  defp profile_display_name(%{user: user, username: username}) do
    full_name =
      case user do
        %{full_name: name} when is_binary(name) -> String.trim(name)
        _ -> ""
      end

    fallback = username |> to_string() |> String.trim()

    if full_name != "" do
      full_name
    else
      fallback
    end
  end

  defp profile_display_name(profile) when is_map(profile) do
    profile
    |> Map.get(:username, "usuario")
    |> to_string()
    |> String.trim()
  end

  defp profile_avatar(%{avatar: %{data: data}} = profile) when is_binary(data) do
    data = String.trim(data)

    if data != "" and String.starts_with?(data, "data:image") do
      data
    else
      fallback_avatar(profile)
    end
  end

  defp profile_avatar(profile) do
    fallback_avatar(profile)
  end

  defp fallback_avatar(profile) do
    seed = profile_display_name(profile)
    "https://api.dicebear.com/7.x/avataaars/svg?seed=#{URI.encode(seed)}&backgroundColor=c0aede"
  end
end
