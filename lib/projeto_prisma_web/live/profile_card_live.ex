defmodule ProjetoPrismaWeb.ProfileCardLive do
  use ProjetoPrismaWeb, :live_view

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.Scope

  @max_pins 4
  @bio_max 90

  @impl true
  def mount(_params, session, socket) do
    current_scope = resolve_current_scope(session)
    profile = Accounts.get_profile_with_user(current_scope)

    # Get full_name from the user associated with the profile
    full_name = get_user_full_name(profile)
    pinned_achievements = safe_list_pinned(current_scope)

    {:ok,
     socket
     |> assign(:current_scope, current_scope)
     |> assign(:profile, profile)
     |> assign(:profile_missing, is_nil(profile))
     |> assign(:modal_open, false)
     |> assign(:modal_error, nil)
     |> assign(:full_name, full_name)
     |> assign(:form, to_form(Accounts.change_profile(current_scope)))
     |> assign(:pinned_achievements, pinned_achievements)
     |> assign(:achievements_modal_open, false)
     |> assign(:achievement_search, "")
     |> assign(:available_achievements, [])
     |> assign(:selected_achievement_ids, [])
     |> assign(:achievements_modal_error, nil)
     |> allow_upload(:avatar,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_entries: 1,
       max_file_size: 2_000_000
     )}
  end

  defp get_user_full_name(nil), do: ""

  defp get_user_full_name(%{user: %{full_name: full_name}}) when is_binary(full_name),
    do: full_name

  defp get_user_full_name(_), do: ""

  @impl true
  def handle_event("open_edit_modal", _params, socket) do
    if socket.assigns.profile_missing do
      {:noreply, put_flash(socket, :error, "Nao foi possivel localizar seu perfil.")}
    else
      full_name = get_user_full_name(socket.assigns.profile)

      {:noreply,
       socket
       |> assign(:modal_open, true)
       |> assign(:modal_error, nil)
       |> assign(:full_name, full_name)
       |> assign(:form, to_form(Accounts.change_profile(socket.assigns.current_scope)))}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:modal_open, false)
     |> assign(:modal_error, nil)
     |> cancel_all_uploads()}
  end

  def handle_event("validate_profile", %{"profile" => params} = full_params, socket) do
    # Track full_name separately (it's a user field, not profile)
    full_name = full_params["full_name"] || socket.assigns.full_name

    changeset =
      socket.assigns.current_scope
      |> Accounts.change_profile(params)
      |> Map.put(:action, :validate)

    changeset =
      if Accounts.username_taken?(socket.assigns.current_scope, params["username"]) do
        Ecto.Changeset.add_error(changeset, :username, "ja esta em uso")
      else
        changeset
      end

    {:noreply,
     socket
     |> assign(:full_name, full_name)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  def handle_event("save_profile", %{"profile" => params} = full_params, socket) do
    username = String.trim(params["username"] || "")
    full_name = full_params["full_name"] || ""
    bio = params["bio"] || ""

    cond do
      # Validate username length
      String.length(username) < 3 ->
        changeset =
          socket.assigns.current_scope
          |> Accounts.change_profile(params)
          |> Ecto.Changeset.add_error(:username, "deve ter no minimo 3 caracteres")
          |> Map.put(:action, :validate)

        {:noreply,
         socket
         |> assign(:modal_error, "Username deve ter no minimo 3 caracteres.")
         |> assign(:form, to_form(changeset))}

      # Validate username format
      not Regex.match?(~r/^[a-zA-Z0-9_]+$/, username) ->
        changeset =
          socket.assigns.current_scope
          |> Accounts.change_profile(params)
          |> Ecto.Changeset.add_error(
            :username,
            "deve conter apenas letras, numeros e underscores"
          )
          |> Map.put(:action, :validate)

        {:noreply,
         socket
         |> assign(:modal_error, "Username deve conter apenas letras, numeros e underscores.")
         |> assign(:form, to_form(changeset))}

      # Validate username is not taken
      Accounts.username_taken?(socket.assigns.current_scope, username) ->
        changeset =
          socket.assigns.current_scope
          |> Accounts.change_profile(params)
          |> Ecto.Changeset.add_error(:username, "ja esta em uso")
          |> Map.put(:action, :validate)

        {:noreply,
         socket
         |> assign(:modal_error, "Username ja esta em uso.")
         |> assign(:form, to_form(changeset))}

      String.length(bio) > @bio_max ->
        changeset =
          socket.assigns.current_scope
          |> Accounts.change_profile(params)
          |> Ecto.Changeset.add_error(:bio, "deve ter no maximo #{@bio_max} caracteres")
          |> Map.put(:action, :validate)

        {:noreply,
         socket
         |> assign(:modal_error, "Bio deve ter no maximo #{@bio_max} caracteres.")
         |> assign(:form, to_form(changeset))}

      true ->
        # Update full_name on users table
        Accounts.update_user_full_name(socket.assigns.current_scope, full_name)

        # Update username on users table (cascades to profiles table)
        Accounts.update_user_username(socket.assigns.current_scope, username)

        # Process uploaded avatar and save to profile_avatars table
        process_and_save_avatar(socket)

        # Update profile bio (username is now handled via cascade)
        profile_params = Map.take(params, ["bio"])

        case Accounts.update_profile(socket.assigns.current_scope, profile_params) do
          {:ok, _profile} ->
            # Reload profile with all associations
            profile = Accounts.get_profile_with_user(socket.assigns.current_scope)

            {:noreply,
             socket
             |> assign(:profile, profile)
             |> assign(:full_name, full_name)
             |> assign(:modal_open, false)
             |> assign(:modal_error, nil)
             |> assign(:form, to_form(Accounts.change_profile(socket.assigns.current_scope)))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply,
             socket
             |> assign(:modal_error, "Verifique os campos destacados.")
             |> assign(:form, to_form(Map.put(changeset, :action, :validate)))}

          {:error, :profile_not_found} ->
            {:noreply, assign(socket, :modal_error, "Nao foi possivel localizar seu perfil.")}
        end
    end
  end

  def handle_event("open_achievements_modal", _params, socket) do
    scope = socket.assigns.current_scope
    available = safe_list_available(scope, "")
    pinned = safe_list_pinned(scope)
    selected_ids = Enum.map(pinned, & &1.id)

    {:noreply,
     socket
     |> assign(:achievements_modal_open, true)
     |> assign(:achievement_search, "")
     |> assign(:available_achievements, available)
     |> assign(:selected_achievement_ids, selected_ids)
     |> assign(:achievements_modal_error, nil)}
  end

  def handle_event("close_achievements_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:achievements_modal_open, false)
     |> assign(:achievements_modal_error, nil)}
  end

  def handle_event("search_achievements", params, socket) do
    query =
      params
      |> Map.get("achievement_search", params["value"] || "")
      |> to_string()

    available = safe_list_available(socket.assigns.current_scope, query)

    {:noreply,
     socket
     |> assign(:achievement_search, query)
     |> assign(:available_achievements, available)}
  end

  def handle_event("toggle_pinned_achievement", %{"id" => raw_id}, socket) do
    id = parse_int(raw_id)
    selected = socket.assigns.selected_achievement_ids

    {new_selected, error} =
      cond do
        id in selected ->
          {List.delete(selected, id), nil}

        length(selected) >= @max_pins ->
          {selected, "Voce so pode fixar ate #{@max_pins} conquistas."}

        true ->
          {selected ++ [id], nil}
      end

    {:noreply,
     socket
     |> assign(:selected_achievement_ids, new_selected)
     |> assign(:achievements_modal_error, error)}
  end

  def handle_event("save_pinned_achievements", _params, socket) do
    scope = socket.assigns.current_scope
    ids = socket.assigns.selected_achievement_ids

    case Accounts.update_pinned_achievements(scope, ids) do
      {:ok, _} ->
        pinned = safe_list_pinned(scope)

        {:noreply,
         socket
         |> assign(:pinned_achievements, pinned)
         |> assign(:achievements_modal_open, false)
         |> assign(:achievements_modal_error, nil)}

      {:error, :too_many_pins} ->
        {:noreply,
         assign(socket, :achievements_modal_error, "Voce so pode fixar ate #{@max_pins} conquistas.")}

      {:error, :invalid_achievement_selection} ->
        {:noreply,
         assign(
           socket,
           :achievements_modal_error,
           "Selecao invalida. Escolha apenas conquistas concluidas."
         )}

      {:error, :profile_not_found} ->
        {:noreply, assign(socket, :achievements_modal_error, "Perfil nao encontrado.")}

      {:error, _other} ->
        {:noreply,
         assign(socket, :achievements_modal_error, "Nao foi possivel salvar suas conquistas.")}
    end
  end

  defp process_and_save_avatar(socket) do
    case uploaded_entries(socket, :avatar) do
      {[entry], []} ->
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          {:ok, binary} = File.read(path)
          content_type = entry.client_type || "image/png"
          base64 = Base.encode64(binary)
          data = "data:#{content_type};base64,#{base64}"

          # Save to profile_avatars table
          Accounts.upsert_profile_avatar(socket.assigns.current_scope, data, content_type)

          {:ok, :saved}
        end)

      _ ->
        :no_upload
    end
  end

  defp cancel_all_uploads(socket) do
    Enum.reduce(socket.assigns.uploads.avatar.entries, socket, fn entry, acc ->
      cancel_upload(acc, :avatar, entry.ref)
    end)
  end

  defp safe_list_pinned(nil), do: []

  defp safe_list_pinned(scope) do
    if function_exported?(Accounts, :list_pinned_achievements, 1) do
      try do
        Accounts.list_pinned_achievements(scope) || []
      rescue
        _ -> []
      end
    else
      []
    end
  end

  defp safe_list_available(nil, _query), do: []

  defp safe_list_available(scope, query) do
    if function_exported?(Accounts, :list_achieved_achievements, 2) do
      try do
        opts = if to_string(query) == "", do: [], else: [search: to_string(query)]
        Accounts.list_achieved_achievements(scope, opts) || []
      rescue
        _ -> []
      end
    else
      []
    end
  end

  defp parse_int(v) when is_integer(v), do: v

  defp parse_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_int(_), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="profile-card card p-6 rounded-2xl" id="profile-card">
      <div class="flex items-start space-x-4">
        <div
          class="relative profile-avatar-container"
          phx-click="open_edit_modal"
          style="cursor: pointer;"
        >
          <img
            src={profile_avatar(@profile)}
            alt={profile_username(@profile)}
            id="profile-avatar"
            class="w-20 h-20 rounded-full border-2 border-blue-400 object-cover"
          />
          <div class="profile-edit-overlay">
            <i class="fas fa-camera text-white text-xl"></i>
          </div>
          <div class="online-indicator pulse"></div>
        </div>
        <div class="flex-1">
          <div class="flex items-center space-x-2 mb-1">
            <h2 class="text-2xl font-bold" id="profile-username">@{profile_username(@profile)}</h2>
          </div>
          <div class="profile-stats flex items-center space-x-3 text-xs text-gray-400">
            <span><strong class="text-white" id="followers-count">0</strong> Seguidores</span>
            <span><strong class="text-white" id="following-count">0</strong> Seguindo</span>
          </div>
        </div>
      </div>

      <div class="mt-4 text-sm text-gray-400" id="profile-bio">
        <p class="profile-bio">{profile_bio(@profile)}</p>
      </div>

    <!-- Pinned Achievements -->
      <div class="mt-6">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-sm font-semibold text-gray-400 uppercase tracking-wider">
            Conquistas Fixadas
          </h3>
          <button
            type="button"
            id="open-pin-modal"
            phx-click="open_achievements_modal"
            class="pinned-manage-btn"
          >
            <i class="fas fa-thumbtack"></i> Gerenciar
          </button>
        </div>
        <div class="pinned-achievements">
          <div class="pinned-grid" id="pinned-grid">
            <%= for achievement <- pinned_with_padding(@pinned_achievements) do %>
              <%= if achievement do %>
                <div class="pinned-achievement" title={achievement_tooltip(achievement)}>
                  <%= if has_icon_image?(achievement) do %>
                    <img
                      src={achievement.icon}
                      alt={achievement.name || "Conquista"}
                      class="achievement-icon-img"
                    />
                  <% else %>
                    <div class="achievement-icon">🏆</div>
                  <% end %>
                  <div class="achievement-name">{achievement.name || "Conquista"}</div>
                </div>
              <% else %>
                <div class="pinned-achievement pinned-empty">
                  <div class="achievement-icon">📌</div>
                  <div class="achievement-name">Vazio</div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>

      <div
        :if={@profile_missing}
        class="mt-4 p-3 bg-red-500/10 border border-red-500/30 rounded-lg text-red-300 text-sm"
        id="profile-missing"
      >
        Perfil nao encontrado. Recarregue a pagina ou faca login novamente.
      </div>
    </div>

    <!-- Edit Profile Modal -->
    <div
      :if={@modal_open}
      id="edit-profile-modal"
      class="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50"
      phx-window-keydown="close_modal"
      phx-key="escape"
    >
      <div
        class="bg-gradient-to-br from-gray-800 to-gray-900 rounded-2xl p-8 max-w-2xl w-full mx-4 shadow-2xl border border-gray-700/50 max-h-[90vh] overflow-y-auto"
        phx-click-away="close_modal"
      >
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-white">Editar Perfil</h2>
          <button
            type="button"
            phx-click="close_modal"
            class="text-gray-400 hover:text-white transition-colors"
          >
            <i class="fas fa-times text-2xl"></i>
          </button>
        </div>

        <.form
          for={@form}
          id="profile-edit-form"
          phx-change="validate_profile"
          phx-submit="save_profile"
        >
          <!-- Avatar Upload Section -->
          <div class="flex flex-col items-center mb-6">
            <div class="relative mb-4">
              <%= if length(@uploads.avatar.entries) > 0 do %>
                <% entry = hd(@uploads.avatar.entries) %>
                <.live_img_preview
                  entry={entry}
                  class="w-32 h-32 rounded-full border-4 border-blue-400 object-cover"
                />
                <button
                  type="button"
                  phx-click="cancel_upload"
                  phx-value-ref={entry.ref}
                  class="absolute -top-2 -right-2 w-8 h-8 bg-red-500 rounded-full flex items-center justify-center text-white hover:bg-red-600 transition-colors"
                >
                  <i class="fas fa-times"></i>
                </button>
              <% else %>
                <img
                  src={profile_avatar(@profile)}
                  alt="Avatar"
                  id="edit-profile-avatar"
                  class="w-32 h-32 rounded-full border-4 border-blue-400 object-cover"
                />
              <% end %>
            </div>

            <h3 class="text-lg font-semibold text-gray-300 mb-2">Foto de Perfil</h3>

            <label class="px-6 py-2 bg-gray-700 hover:bg-gray-600 text-blue-400 font-medium rounded-lg transition-all duration-300 flex items-center gap-2 cursor-pointer">
              <i class="fas fa-camera"></i>
              Escolher Foto <.live_file_input upload={@uploads.avatar} class="hidden" />
            </label>

            <p class="text-gray-500 text-sm mt-2">JPG, PNG, GIF ou WebP. Maximo 2MB.</p>

            <%= for entry <- @uploads.avatar.entries do %>
              <%= for err <- upload_errors(@uploads.avatar, entry) do %>
                <p class="text-red-400 text-sm mt-2">{error_to_string(err)}</p>
              <% end %>
            <% end %>
          </div>

          <div class="space-y-4 mb-6">
            <div>
              <label class="block text-gray-300 font-semibold mb-2">Nome Completo</label>
              <input
                type="text"
                name="full_name"
                value={@full_name}
                id="profile-full-name-input"
                placeholder="Seu nome completo"
                maxlength="100"
                class="w-full px-4 py-3 bg-gray-700/50 text-white rounded-lg border border-gray-600 focus:border-blue-500 focus:outline-none transition-colors"
              />
              <p class="text-gray-500 text-sm mt-2">
                Seu nome real. Sera exibido no seu perfil e em outras areas do sistema.
              </p>
            </div>

            <div>
              <label class="block text-gray-300 font-semibold mb-2">Nickname</label>
              <div class="flex items-center">
                <span class="inline-flex items-center px-3 py-3 bg-gray-800 border border-r-0 border-gray-600 text-gray-300 rounded-l-lg">
                  @
                </span>
                <input
                  type="text"
                  name={@form[:username].name}
                  value={@form[:username].value}
                  id="profile-username-input"
                  placeholder="seunickname"
                  minlength="3"
                  maxlength="50"
                  required
                  autocapitalize="none"
                  class="flex-1 px-4 py-3 bg-gray-700/50 text-white rounded-r-lg border border-l-0 border-gray-600 focus:border-blue-500 focus:outline-none transition-colors"
                />
              </div>
              <p class="text-gray-500 text-sm mt-2">
                Apenas letras minusculas, numeros e underscore. O @ sera exibido automaticamente no
                seu perfil.
              </p>
              <p
                :for={msg <- Enum.map(@form[:username].errors, &translate_error/1)}
                class="text-red-400 text-sm mt-1"
              >
                {msg}
              </p>
            </div>

            <div>
              <label class="block text-gray-300 font-semibold mb-2">Bio</label>
              <textarea
                name={@form[:bio].name}
                id="profile-bio-input"
                placeholder="Conte um pouco sobre voce e seus jogos favoritos"
                maxlength="90"
                rows="3"
                class="w-full px-4 py-3 bg-gray-700/50 text-white rounded-lg border border-gray-600 focus:border-blue-500 focus:outline-none transition-colors resize-none"
              >{@form[:bio].value}</textarea>
              <p class="text-gray-500 text-sm mt-2">Maximo de 90 caracteres.</p>
              <p
                :for={msg <- Enum.map(@form[:bio].errors, &translate_error/1)}
                class="text-red-400 text-sm mt-1"
              >
                {msg}
              </p>
            </div>
          </div>

          <p :if={@modal_error} class="text-red-400 text-sm mb-4" role="alert">{@modal_error}</p>

          <div class="flex gap-4">
            <button
              type="button"
              phx-click="close_modal"
              class="flex-1 py-3 bg-gray-700 hover:bg-gray-600 text-white font-semibold rounded-lg transition-all duration-300"
            >
              Cancelar
            </button>
            <button
              type="submit"
              phx-disable-with="Salvando..."
              class="flex-1 py-3 bg-gradient-to-r from-blue-500 to-blue-600 hover:from-blue-600 hover:to-blue-700 text-white font-bold rounded-lg transition-all duration-300"
            >
              Salvar Alteracoes
            </button>
          </div>
        </.form>
      </div>
    </div>

    <!-- Manage Achievements Modal -->
    <div
      :if={@achievements_modal_open}
      id="manage-achievements-modal"
      class="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50"
      phx-window-keydown="close_achievements_modal"
      phx-key="escape"
    >
      <div
        class="bg-gradient-to-br from-gray-800 to-gray-900 rounded-2xl p-6 max-w-3xl w-full mx-4 shadow-2xl border border-gray-700/50 max-h-[90vh] overflow-y-auto"
        phx-click-away="close_achievements_modal"
      >
        <div class="flex justify-between items-center mb-4">
          <div>
            <h2 class="text-xl font-bold text-white">Gerenciar Conquistas Fixadas</h2>
            <p class="text-xs text-gray-400 mt-1">
              Selecione ate 4 conquistas para fixar no seu perfil.
            </p>
          </div>
          <button
            type="button"
            phx-click="close_achievements_modal"
            class="text-gray-400 hover:text-white transition-colors"
          >
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>

        <form phx-change="search_achievements" phx-submit="search_achievements" class="mb-4">
          <div class="relative">
            <i class="fas fa-search absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"></i>
            <input
              type="text"
              id="achievement-search-input"
              name="achievement_search"
              value={@achievement_search}
              placeholder="Buscar por conquista ou jogo..."
              class="w-full pl-10 pr-4 py-2 bg-gray-700/50 text-white rounded-lg border border-gray-600 focus:border-blue-500 focus:outline-none transition-colors"
              phx-debounce="200"
            />
          </div>
        </form>

        <div class="flex items-center justify-between mb-3">
          <span class="text-sm text-gray-300 font-medium">
            {length(@selected_achievement_ids)}/4 selecionadas
          </span>
          <span :if={@achievements_modal_error} class="text-red-400 text-sm" role="alert">
            {@achievements_modal_error}
          </span>
        </div>

        <%= if Enum.empty?(@available_achievements) do %>
          <div class="text-center py-10 text-gray-400 text-sm">
            Nenhuma conquista encontrada. Conquiste algumas e elas aparecerao aqui!
          </div>
        <% else %>
          <div class="manage-modal-list" id="manage-achievements-list">
            <%= for ach <- @available_achievements do %>
              <% selected? = ach.id in @selected_achievement_ids %>
              <% disabled? =
                not selected? and length(@selected_achievement_ids) >= 4 %>
              <div
                class={[
                  "manage-modal-card",
                  selected? && "is-selected",
                  disabled? && "is-disabled"
                ]}
                phx-click="toggle_pinned_achievement"
                phx-value-id={ach.id}
              >
                <div :if={selected?} class="manage-modal-check">
                  <i class="fas fa-check"></i>
                </div>
                <div class="flex items-center gap-2">
                  <div class="mm-icon-wrap">
                    <%= if has_icon_image?(ach) do %>
                      <img src={ach.icon} alt={ach.name || "Conquista"} />
                    <% else %>
                      🏆
                    <% end %>
                  </div>
                  <div class="min-w-0 flex-1">
                    <div class="mm-name">{ach.name || "Conquista"}</div>
                    <div :if={achievement_game(ach) != ""} class="mm-game">{achievement_game(ach)}</div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <div class="flex gap-3 mt-6">
          <button
            type="button"
            phx-click="close_achievements_modal"
            class="flex-1 py-2.5 bg-gray-700 hover:bg-gray-600 text-white font-semibold rounded-lg transition-all duration-300"
          >
            Cancelar
          </button>
          <button
            type="button"
            phx-click="save_pinned_achievements"
            phx-disable-with="Salvando..."
            class="flex-1 py-2.5 bg-gradient-to-r from-blue-500 to-blue-600 hover:from-blue-600 hover:to-blue-700 text-white font-bold rounded-lg transition-all duration-300"
          >
            Confirmar
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp pinned_with_padding(list) do
    list = list || []
    pad = @max_pins - length(list)
    list ++ List.duplicate(nil, max(pad, 0))
  end

  defp has_icon_image?(%{icon: icon}) when is_binary(icon) do
    icon = String.trim(icon)
    icon != "" and (String.starts_with?(icon, "http") or String.starts_with?(icon, "data:"))
  end

  defp has_icon_image?(_), do: false

  defp achievement_tooltip(%{name: name, game_name: game}) when is_binary(game) and game != "" do
    "#{name || "Conquista"} • #{game}"
  end

  defp achievement_tooltip(%{name: name}), do: name || "Conquista"
  defp achievement_tooltip(_), do: "Conquista"

  defp achievement_game(%{game_name: name}) when is_binary(name), do: String.trim(name)
  defp achievement_game(_), do: ""

  defp error_to_string(:too_large), do: "Arquivo muito grande. Maximo 2MB."

  defp error_to_string(:not_accepted),
    do: "Tipo de arquivo nao aceito. Use JPG, PNG, GIF ou WebP."

  defp error_to_string(:too_many_files), do: "Apenas uma imagem por vez."
  defp error_to_string(_), do: "Erro ao processar arquivo."

  defp resolve_current_scope(%{"user_token" => token}) when is_binary(token) do
    case Accounts.get_user_by_session_token(token) do
      {user, _inserted_at} -> Scope.for_user(user)
      _ -> nil
    end
  end

  defp resolve_current_scope(_session), do: nil

  defp profile_username(%{username: username}) when is_binary(username) do
    String.trim(username)
  end

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

  defp profile_bio(%{bio: bio}) do
    bio = bio |> to_string() |> String.trim()

    if bio == "" do
      "Adicione uma bio curta para destacar seus jogos favoritos."
    else
      bio
    end
  end

  defp profile_bio(_profile) do
    "Adicione uma bio curta para destacar seus jogos favoritos."
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
