defmodule ProjetoPrismaWeb.RegisterFormLive do
  use ProjetoPrismaWeb, :live_view

  alias ProjetoPrisma.Accounts

  @impl true
  def mount(_params, _session, socket) do
    form =
      to_form(
        %{
          "full_name" => "",
          "nickname" => "",
          "email" => "",
          "password" => "",
          "confirm_password" => ""
        },
        as: :register
      )

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:form_errors, [])
     |> assign(:show_password, false)
     |> assign(:show_confirm_password, false)
     |> assign(:registration_complete, false)
     |> assign(:registration_token, nil)}
  end

  @impl true
  def handle_event("toggle_password", %{"field" => field}, socket) do
    case field do
      "password" ->
        {:noreply, assign(socket, :show_password, !socket.assigns.show_password)}

      "confirm_password" ->
        {:noreply, assign(socket, :show_confirm_password, !socket.assigns.show_confirm_password)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("validate", %{"register" => params}, socket) do
    {:noreply,
     socket
     |> assign(:form, to_form(params, as: :register))
     |> assign(:form_errors, [])}
  end

  def handle_event("submit_register", %{"register" => params}, socket) do
    full_name = String.trim(params["full_name"] || "")

    nickname =
      params["nickname"]
      |> String.trim()
      |> String.downcase()
      |> String.replace(~r/\s+/, "_")

    email =
      params["email"]
      |> String.trim()
      |> String.downcase()

    password = params["password"] || ""
    confirm_password = params["confirm_password"] || ""

    cond do
      String.length(full_name) < 3 ->
        {:noreply,
         assign(socket, :form_errors, [{:full_name, "deve ter no minimo 3 caracteres"}])}

      String.length(nickname) < 3 ->
        {:noreply, assign(socket, :form_errors, [{:username, "deve ter no minimo 3 caracteres"}])}

      not Regex.match?(~r/^[a-z0-9_]+$/, nickname) ->
        {:noreply,
         assign(socket, :form_errors, [
           {:username, "deve conter apenas letras minusculas, numeros e underscore (_)"}
         ])}

      String.length(password) < 6 ->
        {:noreply, assign(socket, :form_errors, [{:password, "deve ter no minimo 6 caracteres"}])}

      password != confirm_password ->
        {:noreply,
         assign(socket, :form_errors, [{:confirm_password, "nao coincide com a senha"}])}

      true ->
        register_user(socket, %{
          username: nickname,
          email: email,
          password: password,
          full_name: full_name
        })
    end
  end

  defp register_user(socket, attrs) do
    with {:ok, user} <- Accounts.register_user_legacy(attrs),
         {:ok, profile} <- Accounts.create_profile_for_user(user) do
      token =
        Phoenix.Token.sign(
          ProjetoPrismaWeb.Endpoint,
          "registration",
          %{user_id: user.id, profile_id: profile.id}
        )

      {:noreply,
       socket
       |> assign(:registration_token, token)
       |> assign(:registration_complete, true)}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          changeset
          |> Ecto.Changeset.traverse_errors(fn {msg, opts} -> translate_error({msg, opts}) end)
          |> Enum.flat_map(fn {field, messages} ->
            Enum.map(messages, fn message -> {field, format_error_message(field, message)} end)
          end)

        {:noreply, assign(socket, :form_errors, errors)}
    end
  end

  defp field_label(:full_name), do: "Nome completo"
  defp field_label(:username), do: "Nickname"
  defp field_label(:email), do: "E-mail"
  defp field_label(:password), do: "Senha"
  defp field_label(:confirm_password), do: "Confirmar senha"

  defp field_label(field),
    do: field |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp format_error_message(:username, "has already been taken") do
    "O nome de usuario escolhido já está em uso, por favor altere."
  end

  defp format_error_message(:email, "has already been taken") do
    "Este e-mail já está em uso, escolha outro."
  end

  defp format_error_message(_field, message), do: message

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @registration_complete do %>
      <form
        id="complete-registration-form"
        action="/complete-registration"
        method="post"
        phx-hook="AutoSubmit"
      >
        <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
        <input type="hidden" name="token" value={@registration_token} />
        <p style="text-align: center; color: #a0a0a0;">Finalizando cadastro...</p>
      </form>
    <% else %>
      <div :if={@form_errors != []} class="error-message" id="errorMessage" style="display: flex;">
        <i class="fas fa-exclamation-circle"></i>
        <div class="error-message-content" id="errorText">
          <p class="error-message-title">Verifique os campos abaixo:</p>
          <ul class="error-message-list">
            <li :for={{field, message} <- @form_errors}>
              {field_label(field)}: {message}
            </li>
          </ul>
        </div>
      </div>

      <.form
        for={@form}
        id="registerForm"
        phx-submit="submit_register"
        phx-change="validate"
      >
        <div class="form-group">
          <label class="form-label">Nome Completo</label>
          <div class="input-wrapper">
            <i class="fas fa-user input-icon"></i>
            <input
              type="text"
              name="register[full_name]"
              id="fullName"
              class="form-input"
              placeholder="Seu nome completo"
              value={@form[:full_name].value}
              required
              minlength="3"
            />
          </div>
        </div>

        <div class="form-group">
          <label class="form-label">Nickname</label>
          <div class="input-wrapper">
            <i class="fas fa-at input-icon"></i>
            <input
              type="text"
              name="register[nickname]"
              id="nickname"
              class="form-input"
              placeholder="seu_nickname"
              value={@form[:nickname].value}
              required
              minlength="3"
              style="text-transform: lowercase;"
            />
          </div>
          <p class="nickname-hint">
            Apenas letras minusculas, numeros e underscore. Este sera seu @nome de usuario
          </p>
        </div>

        <div class="form-group">
          <label class="form-label">E-mail</label>
          <div class="input-wrapper">
            <i class="fas fa-envelope input-icon"></i>
            <input
              type="email"
              name="register[email]"
              id="email"
              class="form-input"
              placeholder="seu@email.com"
              value={@form[:email].value}
              required
            />
          </div>
        </div>

        <div class="form-group">
          <label class="form-label">Senha</label>
          <div class="input-wrapper">
            <i class="fas fa-lock input-icon"></i>
            <input
              type={if @show_password, do: "text", else: "password"}
              name="register[password]"
              id="password"
              class="form-input"
              placeholder="digite sua senha"
              value={@form[:password].value}
              required
              minlength="6"
            />
            <button
              type="button"
              class="password-toggle"
              phx-click="toggle_password"
              phx-value-field="password"
            >
              <i
                class={"fas #{if @show_password, do: "fa-eye-slash", else: "fa-eye"}"}
                id="toggleIcon1"
              >
              </i>
            </button>
          </div>
        </div>

        <div class="form-group">
          <label class="form-label">Confirmar Senha</label>
          <div class="input-wrapper">
            <i class="fas fa-lock input-icon"></i>
            <input
              type={if @show_confirm_password, do: "text", else: "password"}
              name="register[confirm_password]"
              id="confirmPassword"
              class="form-input"
              placeholder="confirme sua senha"
              value={@form[:confirm_password].value}
              required
              minlength="6"
            />
            <button
              type="button"
              class="password-toggle"
              phx-click="toggle_password"
              phx-value-field="confirm_password"
            >
              <i
                class={"fas #{if @show_confirm_password, do: "fa-eye-slash", else: "fa-eye"}"}
                id="toggleIcon2"
              >
              </i>
            </button>
          </div>
        </div>

        <button type="submit" class="register-btn" phx-disable-with="Criando conta...">
          Criar Conta
        </button>
      </.form>

      <div class="login-link">
        Ja tem uma conta? <a href="/users/log-in">Voltar para o Login</a>
      </div>
    <% end %>
    """
  end
end
