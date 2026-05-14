defmodule ProjetoPrismaWeb.ConnectPlatformsCardsLive do
  use ProjetoPrismaWeb, :live_view

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.Scope
  alias ProjetoPrisma.Sync.Steam.Client, as: SteamClient
  alias ProjetoPrisma.Sync.RetroAchievements.Client, as: RetroClient
  alias ProjetoPrisma.Utils.Psn.Psn_Auth
  alias ProjetoPrisma.Utils.Psn.Psn_Profile

  @platforms [
    %{
      slug: "steam",
      name: "Steam",
      description: "Vincule sua biblioteca Steam",
      brand_icon: "fab fa-steam",
      icon_class: "icon-steam",
      connected: false
    },
    %{
      slug: "playstation",
      name: "PlayStation",
      description: "Conecte sua conta PSN",
      brand_icon: "fab fa-playstation",
      icon_class: "icon-playstation",
      connected: false
    },
    %{
      slug: "xbox",
      name: "Xbox Live",
      description: "Conecte sua conta Xbox",
      brand_icon: "fab fa-xbox",
      icon_class: "icon-xbox",
      connected: false
    },
    %{
      slug: "retroachievements",
      name: "RetroAchievements",
      description: "Vincule RetroAchievements",
      brand_icon: "fas fa-trophy",
      icon_class: "icon-retro",
      connected: false
    }
  ]

  @impl true
  def mount(_params, session, socket) do
    current_scope = resolve_current_scope(session)
    profile = Accounts.get_profile_with_user(current_scope)
    profile_id = profile && profile.id

    {:ok,
     socket
     |> assign(:current_scope, current_scope)
     |> assign(:profile, profile)
     |> assign(:profile_id, profile_id)
     |> assign(:modal_open, false)
     |> assign(:modal_platform, nil)
     |> assign(:modal_error, nil)
     |> assign(:form, to_form(%{"user_id" => "", "api_key" => ""}, as: :steam))
     |> assign(:psn_form, to_form(%{"psn_id" => "", "api_key" => ""}, as: :psn))
     |> assign(:psn_verification_code, generate_verification_code())
     |> assign(:retro_verification_code, generate_verification_code())
     |> refresh_platforms()}
  end

  defp retro_form do
    to_form(%{"username" => "", "api_key" => ""}, as: :retro)
  end

  defp generate_verification_code do
    chars = ~c"ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    suffix = for _ <- 1..4, into: "", do: <<Enum.random(chars)>>
    "PRISMA-" <> suffix
  end

  @impl true
  def handle_event("platform_action", %{"platform" => "steam"}, socket) do
    platform = Enum.find(socket.assigns.platforms, &(&1.slug == "steam"))

    cond do
      is_nil(platform) ->
        {:noreply, put_flash(socket, :error, "Plataforma Steam não encontrada na tela")}

      platform.connected ->
        disconnect_steam(socket)

      true ->
        {:noreply,
         socket
         |> assign(:modal_open, true)
         |> assign(:modal_platform, platform)
         |> assign(:modal_error, nil)
         |> assign(:form, to_form(%{"user_id" => "", "api_key" => ""}, as: :steam))}
    end
  end

  def handle_event("platform_action", %{"platform" => "retroachievements"}, socket) do
    platform = Enum.find(socket.assigns.platforms, &(&1.slug == "retroachievements"))

    cond do
      is_nil(platform) ->
        {:noreply,
         put_flash(socket, :error, "Plataforma RetroAchievements não encontrada na tela")}

      platform.connected ->
        disconnect_retro(socket)

      true ->
        {:noreply,
         socket
         |> assign(:modal_open, true)
         |> assign(:modal_platform, platform)
         |> assign(:modal_error, nil)
         |> assign(:form, retro_form())}
    end
  end

  def handle_event("platform_action", %{"platform" => "playstation"}, socket) do
    platform = Enum.find(socket.assigns.platforms, &(&1.slug == "playstation"))

    cond do
      is_nil(platform) ->
        {:noreply, put_flash(socket, :error, "Plataforma PlayStation não encontrada na tela")}

      platform.connected ->
        disconnect_psn(socket)

      true ->
        {:noreply,
         socket
         |> assign(:modal_open, true)
         |> assign(:modal_platform, platform)
         |> assign(:modal_error, nil)
         |> assign(:psn_form, to_form(%{"psn_id" => "", "api_key" => ""}, as: :psn))}
    end
  end

  def handle_event("platform_action", %{"platform" => "xbox"}, socket) do
    platform = Enum.find(socket.assigns.platforms, &(&1.slug == "xbox"))

    cond do
      is_nil(platform) ->
        {:noreply, put_flash(socket, :error, "Plataforma Xbox não encontrada na tela")}

      platform.connected ->
        disconnect_xbox(socket)

      is_nil(socket.assigns.profile_id) ->
        {:noreply, put_flash(socket, :error, "Não foi possível identificar o perfil atual")}

      true ->
        {:noreply, redirect(socket, to: ~p"/auth/xbox/start")}
    end
  end

  def handle_event("platform_action", %{"platform" => _platform_slug}, socket) do
    {:noreply,
     put_flash(
       socket,
       :info,
       "A conexão desta plataforma será implementada por outro time."
     )}
  end

  defp disconnect_xbox(socket) do
    case Accounts.disconnect_platform_account(socket.assigns.profile_id, "xbox") do
      {:ok, _} ->
        {:noreply,
         socket
         |> refresh_platforms()
         |> put_flash(:info, "Conta Xbox desvinculada")}

      {:error, :platform_not_found} ->
        {:noreply, put_flash(socket, :error, "Plataforma Xbox não cadastrada")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Não foi possível desvincular a conta Xbox")}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:modal_open, false)
     |> assign(:modal_platform, nil)
     |> assign(:modal_error, nil)
     |> assign(:form, to_form(%{"user_id" => "", "api_key" => ""}, as: :steam))
     |> assign(:psn_form, to_form(%{"psn_id" => "", "api_key" => ""}, as: :psn))}
  end

  def handle_event("save_steam_connection", %{"steam" => steam_params}, socket) do
    steam_id = String.trim(steam_params["user_id"] || "")
    api_key = String.trim(steam_params["api_key"] || "")

    cond do
      is_nil(socket.assigns.profile_id) ->
        {:noreply,
         socket
         |> assign(:modal_error, "Não foi possível identificar o perfil atual")
         |> put_flash(:error, "Não foi possível identificar o perfil atual")}

      steam_id == "" or api_key == "" ->
        {:noreply,
         socket
         |> assign(:modal_error, "Preencha Steam ID e API Key para continuar")
         |> put_flash(:error, "Preencha Steam ID e API Key para continuar")
         |> assign(:form, to_form(%{"user_id" => steam_id, "api_key" => api_key}, as: :steam))}

      not valid_steam_id?(steam_id) ->
        {:noreply,
         socket
         |> assign(:modal_error, "Steam ID inválido. Use o SteamID64 com 17 dígitos")
         |> put_flash(:error, "Steam ID inválido. Use o SteamID64 com 17 dígitos")
         |> assign(:form, to_form(%{"user_id" => steam_id, "api_key" => api_key}, as: :steam))}

      true ->
        connect_steam(socket, steam_id, api_key)
    end
  end

  def handle_event("save_retro_connection", %{"retro" => retro_params}, socket) do
    username = String.trim(retro_params["username"] || "")
    api_key = String.trim(retro_params["api_key"] || "")

    cond do
      is_nil(socket.assigns.profile_id) ->
        {:noreply,
         socket
         |> assign(:modal_error, "Não foi possível identificar o perfil atual")
         |> put_flash(:error, "Não foi possível identificar o perfil atual")}

      username == "" or api_key == "" ->
        {:noreply,
         socket
         |> assign(:modal_error, "Preencha Username e API Key para continuar")
         |> put_flash(:error, "Preencha Username e API Key para continuar")
         |> assign(:form, to_form(%{"username" => username, "api_key" => api_key}, as: :retro))}

      true ->
        connect_retro(socket, username, api_key)
    end
  end

  def handle_event("save_psn_connection", %{"psn" => psn_params}, socket) do
    psn_id = String.trim(psn_params["psn_id"] || "")
    npsso = String.trim(psn_params["api_key"] || "")

    cond do
      is_nil(socket.assigns.profile_id) ->
        {:noreply,
         socket
         |> assign(:modal_error, "Não foi possível identificar o perfil atual")
         |> put_flash(:error, "Não foi possível identificar o perfil atual")}

      psn_id == "" or npsso == "" ->
        {:noreply,
         socket
         |> assign(:modal_error, "Preencha PSN ID e Token de Acesso para continuar")
         |> put_flash(:error, "Preencha PSN ID e Token de Acesso para continuar")
         |> assign(:psn_form, to_form(%{"psn_id" => psn_id, "api_key" => npsso}, as: :psn))}

      true ->
        connect_psn(socket, psn_id, npsso)
    end
  end

  defp resolve_current_scope(%{"user_token" => token}) when is_binary(token) do
    case Accounts.get_user_by_session_token(token) do
      {user, _inserted_at} -> Scope.for_user(user)
      _ -> nil
    end
  end

  defp resolve_current_scope(_session), do: nil

  defp list_connected_slugs(nil), do: []
  defp list_connected_slugs(profile_id), do: Accounts.list_connected_platform_slugs(profile_id)

  defp refresh_platforms(socket) do
    connected_slugs = list_connected_slugs(socket.assigns.profile_id)
    assign(socket, :platforms, with_connection_status(@platforms, connected_slugs))
  end

  defp with_connection_status(platforms, connected_slugs) do
    connected_set = MapSet.new(connected_slugs)

    Enum.map(platforms, fn platform ->
      connected = MapSet.member?(connected_set, platform.slug)
      Map.put(platform, :connected, connected)
    end)
  end

  defp connect_steam(socket, steam_id, api_key) do
    with :ok <- validate_steam_credentials(steam_id, api_key),
         {:ok, _account} <-
           Accounts.connect_platform_account(socket.assigns.profile_id, "steam", %{
             "external_user_id" => steam_id,
             "profile_url" => "https://steamcommunity.com/profiles/#{steam_id}",
             "api_key" => api_key
           }) do
      {:noreply,
       socket
       |> refresh_platforms()
       |> assign(:modal_open, false)
       |> assign(:modal_platform, nil)
       |> assign(:modal_error, nil)
       |> assign(:form, to_form(%{"user_id" => "", "api_key" => ""}, as: :steam))
       |> put_flash(:info, "Conta Steam vinculada com sucesso")}
    else
      {:error, :platform_not_found} ->
        {:noreply,
         socket
         |> assign(
           :modal_error,
           "Plataforma Steam não encontrada no banco. Rode o seed para cadastrar as plataformas."
         )
         |> put_flash(
           :error,
           "Plataforma Steam não encontrada no banco. Rode o seed para cadastrar as plataformas."
         )}

      {:error, :invalid_credentials} ->
        {:noreply,
         socket
         |> assign(:modal_error, "Falha na validação da Steam. Confira Steam ID e API Key")
         |> put_flash(:error, "Falha na validação da Steam. Confira Steam ID e API Key")
         |> assign(:form, to_form(%{"user_id" => steam_id, "api_key" => api_key}, as: :steam))}

      {:error, {:steam_http_status, status}} ->
        {:noreply,
         socket
         |> assign(
           :modal_error,
           "Steam respondeu com status #{status}. Verifique os dados e tente novamente"
         )
         |> put_flash(
           :error,
           "Steam respondeu com status #{status}. Verifique os dados e tente novamente"
         )
         |> assign(:form, to_form(%{"user_id" => steam_id, "api_key" => api_key}, as: :steam))}

      {:error, :steam_request_failed} ->
        {:noreply,
         socket
         |> assign(:modal_error, "Não foi possível validar com a API da Steam agora")
         |> put_flash(:error, "Não foi possível validar com a API da Steam agora")
         |> assign(:form, to_form(%{"user_id" => steam_id, "api_key" => api_key}, as: :steam))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:modal_error, "Não foi possível salvar a conexão Steam")
         |> put_flash(:error, "Não foi possível salvar a conexão Steam")
         |> assign(:form, to_form(%{"user_id" => steam_id, "api_key" => api_key}, as: :steam))}
    end
  end

  defp connect_psn(socket, psn_id, npsso) do
    code = socket.assigns.psn_verification_code

    with {:ok, auth} <- Psn_Auth.authenticate(npsso),
         {:ok, profile} <- Psn_Profile.get_profile_from_username(auth.access_token, psn_id),
         :ok <- check_about_me_code(profile, code),
         {:ok, _account} <-
           Accounts.connect_platform_account(socket.assigns.profile_id, "playstation", %{
             "external_user_id" => profile.account_id,
             "profile_url" => "",
             "api_key" => npsso
           }) do
      {:noreply,
       socket
       |> refresh_platforms()
       |> assign(:modal_open, false)
       |> assign(:modal_platform, nil)
       |> assign(:modal_error, nil)
       |> assign(:psn_form, to_form(%{"psn_id" => "", "api_key" => ""}, as: :psn))
       |> assign(:psn_verification_code, generate_verification_code())
       |> put_flash(:info, "Conta PlayStation vinculada com sucesso")}
    else
      {:error, :platform_not_found} ->
        {:noreply,
         socket
         |> assign(
           :modal_error,
           "Plataforma PlayStation não encontrada no banco. Rode o seed para cadastrar as plataformas."
         )
         |> put_flash(
           :error,
           "Plataforma PlayStation não encontrada no banco. Rode o seed para cadastrar as plataformas."
         )}

      {:error, :verification_code_missing} ->
        {:noreply,
         socket
         |> assign(
           :modal_error,
           "Não encontramos o código de verificação no seu 'Sobre Mim'. Confirme que colou o código mostrado acima no seu perfil PlayStation, salve e aguarde alguns segundos antes de tentar novamente."
         )
         |> put_flash(:error, "Código de verificação não encontrado no 'Sobre Mim'")
         |> assign(:psn_form, to_form(%{"psn_id" => psn_id, "api_key" => npsso}, as: :psn))}

      {:error, :invalid_credentials} ->
        {:noreply,
         socket
         |> assign(:modal_error, "Falha na validação da PSN. Confira PSN ID e Token de Acesso")
         |> put_flash(:error, "Falha na validação da PSN. Confira PSN ID e Token de Acesso")
         |> assign(:psn_form, to_form(%{"psn_id" => "", "api_key" => ""}, as: :psn))}

      {:error, {:psn_http_status, 401}} ->
        {:noreply,
         socket
         |> assign(
           :modal_error,
           "Token de Acesso expirado ou inválido. Gere um novo Token em " <>
             "ca.account.sony.com/api/v1/ssocookie"
         )
         |> put_flash(:error, "Token PSN expirado")
         |> assign(:psn_form, to_form(%{"psn_id" => "", "api_key" => ""}, as: :psn))}

      {:error, {:psn_http_status, 404}} ->
        {:noreply,
         socket
         |> assign(
           :modal_error,
           "PSN ID não encontrado. Verifique se o nome de usuário está correto."
         )
         |> put_flash(:error, "PSN ID não encontrado")
         |> assign(:psn_form, to_form(%{"psn_id" => "", "api_key" => ""}, as: :psn))}

      {:error, {:psn_http_status, status}} ->
        {:noreply,
         socket
         |> assign(
           :modal_error,
           "PlayStation respondeu com status #{status}. Verifique os dados e tente novamente"
         )
         |> put_flash(
           :error,
           "PlayStation respondeu com status #{status}. Verifique os dados e tente novamente"
         )
         |> assign(:psn_form, to_form(%{"psn_id" => "", "api_key" => ""}, as: :psn))}

      {:error, :psn_request_failed} ->
        {:noreply,
         socket
         |> assign(:modal_error, "Não foi possível validar com a API da PSN agora")
         |> put_flash(:error, "Não foi possível validar com a API da PSN agora")
         |> assign(:psn_form, to_form(%{"psn_id" => "", "api_key" => ""}, as: :psn))}

      {:error, :tosua_required} ->
        {:noreply,
         socket
         |> assign(
           :modal_error,
           "Sua conta Sony requer que você reaceite os Termos de Uso. " <>
             "Acesse playstation.com, faça login, aceite os termos e gere um novo Token em " <>
             "ca.account.sony.com/api/v1/ssocookie"
         )
         |> put_flash(:error, "Reaceite os Termos de Uso da Sony e gere um novo Token de Acesso")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:modal_error, "Não foi possível salvar a conexão PlayStation")
         |> put_flash(:error, "Não foi possível salvar a conexão PlayStation")
         |> assign(:psn_form, to_form(%{"psn_id" => psn_id, "api_key" => npsso}, as: :psn))}
    end
  end

  defp disconnect_psn(socket) do
    case Accounts.disconnect_platform_account(socket.assigns.profile_id, "playstation") do
      {:ok, _} ->
        {:noreply,
         socket
         |> refresh_platforms()
         |> put_flash(:info, "Conta PlayStation desvinculada")}

      {:error, :platform_not_found} ->
        {:noreply, put_flash(socket, :error, "Plataforma PlayStation não cadastrada")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Não foi possível desvincular a conta PlayStation")}
    end
  end

  # defp validate_psn_credentials(psn_id, npsso) do
  #   case PsnClient.get_player_profile(psn_id, npsso) do
  #     {:ok, %{status: 200, body: %{"profile" => _profile}}} ->
  #       :ok

  #     {:ok, %{status: 200}} ->
  #       {:error, :invalid_credentials}

  #     {:ok, %{status: status}} ->
  #       {:error, {:psn_http_status, status}}

  #     {:error, _reason} ->
  #       {:error, :psn_request_failed}
  #   end
  # end

  defp disconnect_steam(socket) do
    case Accounts.disconnect_platform_account(socket.assigns.profile_id, "steam") do
      {:ok, _} ->
        {:noreply,
         socket
         |> refresh_platforms()
         |> put_flash(:info, "Conta Steam desvinculada")}

      {:error, :platform_not_found} ->
        {:noreply, put_flash(socket, :error, "Plataforma Steam não cadastrada")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Não foi possível desvincular a conta Steam")}
    end
  end

  defp connect_retro(socket, username, api_key) do
    code = socket.assigns.retro_verification_code

    with {:ok, body} <- validate_retro_credentials(username, api_key),
         :ok <- check_motto_code(body, code),
         {:ok, _account} <-
           Accounts.connect_platform_account(socket.assigns.profile_id, "retroachievements", %{
             "external_user_id" => username,
             "profile_url" => "https://retroachievements.org/user/#{username}",
             "api_key" => api_key
           }) do
      {:noreply,
       socket
       |> refresh_platforms()
       |> assign(:modal_open, false)
       |> assign(:modal_platform, nil)
       |> assign(:modal_error, nil)
       |> assign(:form, retro_form())
       |> assign(:retro_verification_code, generate_verification_code())
       |> put_flash(:info, "Conta RetroAchievements vinculada com sucesso")}
    else
      {:error, :verification_code_missing} ->
        {:noreply,
         socket
         |> assign(
           :modal_error,
           "Não encontramos o código de verificação no campo 'Motto' do seu perfil RetroAchievements. Confirme que colou o código mostrado acima, salve e tente novamente."
         )
         |> put_flash(:error, "Código de verificação não encontrado no Motto")
         |> assign(:form, to_form(%{"username" => username, "api_key" => api_key}, as: :retro))}

      {:error, :platform_not_found} ->
        {:noreply,
         socket
         |> assign(
           :modal_error,
           "Plataforma RetroAchievements não encontrada no banco. Rode o seed para cadastrar as plataformas."
         )
         |> put_flash(
           :error,
           "Plataforma RetroAchievements não encontrada no banco. Rode o seed para cadastrar as plataformas."
         )
         |> assign(:form, to_form(%{"username" => username, "api_key" => api_key}, as: :retro))}

      {:error, :invalid_credentials} ->
        {:noreply,
         socket
         |> assign(:modal_error, "Falha na validação. Confira Username e API Key")
         |> put_flash(:error, "Falha na validação. Confira Username e API Key")
         |> assign(:form, to_form(%{"username" => username, "api_key" => api_key}, as: :retro))}

      {:error, {:retro_http_status, status}} ->
        {:noreply,
         socket
         |> assign(
           :modal_error,
           "RetroAchievements respondeu com status #{status}. Verifique os dados e tente novamente"
         )
         |> put_flash(
           :error,
           "RetroAchievements respondeu com status #{status}. Verifique os dados e tente novamente"
         )
         |> assign(:form, to_form(%{"username" => username, "api_key" => api_key}, as: :retro))}

      {:error, :retro_request_failed} ->
        {:noreply,
         socket
         |> assign(:modal_error, "Não foi possível validar com a API do RetroAchievements agora")
         |> put_flash(:error, "Não foi possível validar com a API do RetroAchievements agora")
         |> assign(:form, to_form(%{"username" => username, "api_key" => api_key}, as: :retro))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:modal_error, "Não foi possível salvar a conexão RetroAchievements")
         |> put_flash(:error, "Não foi possível salvar a conexão RetroAchievements")
         |> assign(:form, to_form(%{"username" => username, "api_key" => api_key}, as: :retro))}
    end
  end

  defp disconnect_retro(socket) do
    case Accounts.disconnect_platform_account(socket.assigns.profile_id, "retroachievements") do
      {:ok, _} ->
        {:noreply,
         socket
         |> refresh_platforms()
         |> put_flash(:info, "Conta RetroAchievements desvinculada")}

      {:error, :platform_not_found} ->
        {:noreply, put_flash(socket, :error, "Plataforma RetroAchievements não cadastrada")}

      {:error, _reason} ->
        {:noreply,
         put_flash(socket, :error, "Não foi possível desvincular a conta RetroAchievements")}
    end
  end

  defp check_about_me_code(%{about_me: about_me}, code)
       when is_binary(about_me) and is_binary(code) do
    if String.contains?(about_me, code), do: :ok, else: {:error, :verification_code_missing}
  end

  defp check_about_me_code(_profile, _code), do: {:error, :verification_code_missing}

  defp check_motto_code(body, code) when is_map(body) and is_binary(code) do
    motto = body["Motto"] || ""

    if is_binary(motto) and String.contains?(motto, code),
      do: :ok,
      else: {:error, :verification_code_missing}
  end

  defp check_motto_code(_body, _code), do: {:error, :verification_code_missing}

  defp validate_steam_credentials(steam_id, api_key) do
    case SteamClient.get_player_summary(steam_id, api_key) do
      {:ok, %{status: 200, body: %{"response" => %{"players" => players}}}}
      when is_list(players) and players != [] ->
        :ok

      {:ok, %{status: 200}} ->
        {:error, :invalid_credentials}

      {:ok, %{status: status}} ->
        {:error, {:steam_http_status, status}}

      {:error, _reason} ->
        {:error, :steam_request_failed}
    end
  end

  defp valid_steam_id?(steam_id), do: String.match?(steam_id, ~r/^\d{17}$/)

  defp validate_retro_credentials(username, api_key) do
    case RetroClient.get_player_profile(username, api_key) do
      {:ok, %{status: 200, body: body}} when is_map(body) and body != %{} ->
        {:ok, body}

      {:ok, %{status: 200}} ->
        {:error, :invalid_credentials}

      {:ok, %{status: status}} ->
        {:error, {:retro_http_status, status}}

      {:error, _reason} ->
        {:error, :retro_request_failed}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      :if={@modal_open and @modal_platform}
      id="platform-modal"
      class={["connect-modal-overlay", @modal_open && "active"]}
      phx-window-keydown="close_modal"
      phx-key="escape"
    >
      <div class="connect-modal-container" phx-click-away="close_modal">
        <div class="connect-modal-header">
          <div class={["platform-icon", @modal_platform.icon_class]}>
            <i class={@modal_platform.brand_icon}></i>
          </div>
          <div>
            <h3 class="connect-modal-title">{@modal_platform.name}</h3>
            <p class="connect-modal-subtitle">Configuração de API</p>
          </div>
        </div>

        <.form
          for={
            cond do
              @modal_platform.slug == "steam" -> @form
              @modal_platform.slug == "retroachievements" -> @form
              @modal_platform.slug == "playstation" -> @psn_form
              true -> @form
            end
          }
          id={"#{@modal_platform.slug}-connect-form"}
          phx-submit={
            cond do
              @modal_platform.slug == "steam" -> "save_steam_connection"
              @modal_platform.slug == "retroachievements" -> "save_retro_connection"
              @modal_platform.slug == "playstation" -> "save_psn_connection"
              true -> "save_steam_connection"
            end
          }
        >
          <div class="connect-modal-body">
            <%= if @modal_platform.slug == "steam" do %>
              <p class="connect-modal-instruction">
                Insira seu SteamID64 (17 dígitos) e sua chave de API para validar e vincular a conta.
              </p>

              <p :if={@modal_error} class="connect-modal-error" role="alert">{@modal_error}</p>

              <div class="connect-input-group">
                <label class="connect-input-label" for="steam-user-id">Steam ID</label>
                <.input
                  field={@form[:user_id]}
                  id="steam-user-id"
                  type="text"
                  class="connect-modal-input"
                  placeholder="7656119..."
                />
              </div>

              <div class="connect-input-group">
                <label class="connect-input-label" for="steam-api-key">Steam API Key</label>
                <.input
                  field={@form[:api_key]}
                  id="steam-api-key"
                  type="password"
                  class="connect-modal-input"
                  placeholder="Sua chave da Steam"
                />
              </div>
            <% else %>
              <%= if @modal_platform.slug == "playstation" do %>
                <p class="connect-modal-instruction">
                  <strong>1) Confirme que esta conta é sua:</strong>
                  <br />
                  Adicione o código abaixo em qualquer ponto do seu campo "Sobre Mim" no perfil PlayStation antes de clicar em Vincular. Você não precisa apagar o texto existente — basta colar o código no início, no fim ou entre o que já está lá. O PlayStation pode levar alguns segundos para refletir a alteração.
                </p>

                <div
                  class="connect-input-group"
                  style="background:#0f172a;border:1px solid #334155;border-radius:8px;padding:12px;text-align:center;"
                >
                  <div style="font-size:0.75rem;opacity:0.7;margin-bottom:4px;">
                    Código de verificação
                  </div>
                  <div
                    id="psn-verification-code"
                    style="font-family:monospace;font-size:1.25rem;letter-spacing:0.1em;font-weight:bold;"
                  >
                    {@psn_verification_code}
                  </div>
                </div>

                <p class="connect-modal-instruction">
                  <strong>2) Insira suas credenciais:</strong>
                  <br /> PSN ID e Token de Acesso (NPSSO). Obtenha o NPSSO em
                  <a
                    href="https://ca.account.sony.com/api/v1/ssocookie"
                    target="_blank"
                    rel="noopener noreferrer"
                    style="color: #3b82f6; text-decoration: underline;"
                  >
                    https://ca.account.sony.com/api/v1/ssocookie
                  </a>
                  enquanto conectado na sua conta PlayStation.
                </p>

                <p :if={@modal_error} class="connect-modal-error" role="alert">{@modal_error}</p>

                <div class="connect-input-group">
                  <label class="connect-input-label" for="psn-user-id">PSN ID</label>
                  <.input
                    field={@psn_form[:psn_id]}
                    id="psn-user-id"
                    type="text"
                    class="connect-modal-input"
                    placeholder="seu_username_psn"
                  />
                </div>

                <div class="connect-input-group">
                  <label class="connect-input-label" for="psn-api-key">Token de Acesso</label>
                  <.input
                    field={@psn_form[:api_key]}
                    id="psn-api-key"
                    type="password"
                    class="connect-modal-input"
                    placeholder="Seu token de acesso da PSN"
                  />
                </div>
              <% else %>
                <p class="connect-modal-instruction">
                  <strong>1) Confirme que esta conta é sua:</strong>
                  <br />
                  Adicione o código abaixo em qualquer ponto do campo "Motto" do seu perfil RetroAchievements antes de clicar em Vincular. Você pode mantê-lo junto com seu texto atual.
                  <br />
                  <a
                    href="https://retroachievements.org/controlpanel.php"
                    target="_blank"
                    rel="noopener noreferrer"
                    style="color: #3b82f6; text-decoration: underline;"
                  >
                    Abrir configurações do RetroAchievements
                  </a>
                </p>

                <div
                  class="connect-input-group"
                  style="background:#0f172a;border:1px solid #334155;border-radius:8px;padding:12px;text-align:center;"
                >
                  <div style="font-size:0.75rem;opacity:0.7;margin-bottom:4px;">
                    Código de verificação
                  </div>
                  <div
                    id="retro-verification-code"
                    style="font-family:monospace;font-size:1.25rem;letter-spacing:0.1em;font-weight:bold;"
                  >
                    {@retro_verification_code}
                  </div>
                </div>

                <p class="connect-modal-instruction">
                  <strong>2) Insira suas credenciais:</strong>
                  <br />
                  Nome de usuário e Web API Key (disponível no menu de configurações do RetroAchievements).
                </p>

                <p :if={@modal_error} class="connect-modal-error" role="alert">{@modal_error}</p>

                <div class="connect-input-group">
                  <label class="connect-input-label" for="retro-username">Username</label>
                  <.input
                    field={@form[:username]}
                    id="retro-username"
                    type="text"
                    class="connect-modal-input"
                    placeholder="Seu usuário do RetroAchievements"
                  />
                </div>

                <div class="connect-input-group">
                  <label class="connect-input-label" for="retro-api-key">API Key</label>
                  <.input
                    field={@form[:api_key]}
                    id="retro-api-key"
                    type="password"
                    class="connect-modal-input"
                    placeholder="Sua chave de API"
                  />
                </div>
              <% end %>
            <% end %>
          </div>

          <div class="connect-modal-actions">
            <button type="button" class="btn-cancel" phx-click="close_modal">Sair</button>
            <button type="submit" class="btn-save" phx-disable-with="Validando...">
              Vincular Conta
            </button>
          </div>
        </.form>
      </div>
    </div>

    <div
      :if={Enum.any?(@platforms, & &1.connected)}
      class="connect-continue-wrap"
      id="connect-platforms-home-cta"
    >
      <.link
        navigate={~p"/"}
        class="connect-continue-btn"
      >
        <.icon name="hero-arrow-right" class="size-4" /> Continuar depois
      </.link>
    </div>

    <div class="platforms-grid" id="platforms-grid" phx-update="replace">
      <div :for={platform <- @platforms} class="platform-card" id={"platform-card-#{platform.slug}"}>
        <div class="platform-header">
          <div class={["platform-icon", platform.icon_class]}>
            <i class={[platform.brand_icon, "platform-fa"]}></i>
          </div>
          <div class="platform-info">
            <h3 class="platform-name">{platform.name}</h3>
            <p class="platform-description">{platform.description}</p>
          </div>
        </div>

        <button
          type="button"
          phx-click="platform_action"
          phx-value-platform={platform.slug}
          data-confirm={
            cond do
              platform.connected && platform.slug == "steam" ->
                "Deseja desvincular sua conta Steam?"

              platform.connected && platform.slug == "playstation" ->
                "Deseja desvincular sua conta PlayStation?"

              platform.connected && platform.slug == "retroachievements" ->
                "Deseja desvincular sua conta RetroAchievements?"

              platform.connected && platform.slug == "xbox" ->
                "Deseja desvincular sua conta Xbox?"

              true ->
                nil
            end
          }
          class={[
            "connect-btn",
            platform.connected && "connected"
          ]}
          data-platform={platform.slug}
          id={"connect-btn-#{platform.slug}"}
        >
          <span :if={platform.connected}>
            <.icon name="hero-check" class="size-4 inline-block mr-2" /> Vinculado
          </span>
          <span :if={!platform.connected}>
            <i class="fas fa-link mr-2" aria-hidden="true"></i> Conectar
          </span>
        </button>
      </div>
    </div>
    """
  end
end
