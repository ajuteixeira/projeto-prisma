defmodule ProjetoPrismaWeb.UserSettingsController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.Accounts
  alias ProjetoPrismaWeb.UserAuth

  plug :assign_email_and_password_changesets when action in [:edit, :update]

  def edit(conn, _params) do
    render(conn, :edit)
  end

  def delete(conn, _params) do
    user = conn.assigns.current_scope.user

    case Accounts.soft_delete_user(user) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Sua conta foi excluída.")
        |> UserAuth.log_out_user()

      {:error, _} ->
        conn
        |> put_flash(:error, "Não foi possível excluir a conta. Tente novamente.")
        |> redirect(to: ~p"/users/settings")
    end
  end

  def update(conn, %{"action" => "update_email"} = params) do
    %{"user" => user_params} = params
    user = conn.assigns.current_scope.user

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        conn
        |> put_flash(
          :info,
          "Enviamos um link para confirmar a alteracao de e-mail no novo endereco."
        )
        |> redirect(to: ~p"/users/settings")

      changeset ->
        render(conn, :edit, email_changeset: %{changeset | action: :insert})
    end
  end

  def update(conn, %{"action" => "update_password"} = params) do
    %{"user" => user_params} = params
    user = conn.assigns.current_scope.user

    case Accounts.update_user_password(user, user_params) do
      {:ok, {user, _}} ->
        conn
        |> put_flash(:info, "Senha atualizada com sucesso.")
        |> put_session(:user_return_to, ~p"/users/settings")
        |> UserAuth.log_in_user(user)

      {:error, changeset} ->
        render(conn, :edit, password_changeset: changeset)
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.update_user_email(conn.assigns.current_scope.user, token) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "E-mail alterado com sucesso.")
        |> redirect(to: ~p"/users/settings")

      {:error, _} ->
        conn
        |> put_flash(:error, "O link de alteracao de e-mail e invalido ou expirou.")
        |> redirect(to: ~p"/users/settings")
    end
  end

  defp assign_email_and_password_changesets(conn, _opts) do
    user = conn.assigns.current_scope.user

    conn
    |> assign(:email_changeset, Accounts.change_user_email(user))
    |> assign(:password_changeset, Accounts.change_user_password(user))
  end
end
