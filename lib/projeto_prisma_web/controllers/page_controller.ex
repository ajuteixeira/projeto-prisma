defmodule ProjetoPrismaWeb.PageController do
  use ProjetoPrismaWeb, :controller

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.Scope
  alias ProjetoPrisma.Sync.SyncService
  alias ProjetoPrismaWeb.UserAuth

  def home(conn, _params) do
    render(conn, :home)
  end

  def connect_platforms(conn, _params) do
    render(conn, :connect_platforms)
  end

  def profile(conn, _params) do
    conn = prepare_dashboard_sync(conn)
    render(conn, :profile)
  end

  def followers(conn, _params) do
    render(conn, :followers)
  end

  def register(conn, _params) do
    redirect(conn, to: ~p"/users/register")
  end

  def complete_registration(conn, %{"token" => token}) do
    case Phoenix.Token.verify(ProjetoPrismaWeb.Endpoint, "registration", token, max_age: 300) do
      {:ok, %{user_id: user_id, profile_id: profile_id}} ->
        user = Accounts.get_user!(user_id)

        conn
        |> put_session(:user_return_to, "/connect-platforms")
        |> UserAuth.log_in_user(user)
        |> put_session(:profile_id, profile_id)
        |> put_flash(:info, "Conta criada com sucesso!")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Link de registro expirado ou invalido")
        |> redirect(to: ~p"/register")
    end
  end

  def complete_registration(conn, _params) do
    conn
    |> put_flash(:error, "Token de registro invalido")
    |> redirect(to: ~p"/register")
  end

  defp prepare_dashboard_sync(conn) do
    case resolve_profile_id_from_conn(conn) do
      {:ok, profile_id} ->
        sync_popup = dashboard_sync_popup(profile_id)

        conn
        |> assign(:profile_id, profile_id)
        |> assign(:sync_popup, sync_popup)
        |> maybe_start_dashboard_sync(profile_id, sync_popup)

      _ ->
        assign(conn, :sync_popup, nil)
    end
  end

  defp maybe_start_dashboard_sync(conn, _profile_id, %{status: :running}), do: conn
  defp maybe_start_dashboard_sync(conn, _profile_id, %{status: :failed}), do: conn

  defp maybe_start_dashboard_sync(conn, profile_id, %{status: :idle}) do
    _ = Task.start(fn -> SyncService.sync_connected_platforms(profile_id) end)

    assign(conn, :sync_popup, %{
      status: :running,
      title: "Sincronizando suas contas",
      message: "Atualizando jogos e troféus em segundo plano.",
      progress: true,
      count: nil
    })
  end

  defp maybe_start_dashboard_sync(conn, _profile_id, _), do: conn

  defp dashboard_sync_popup(profile_id) do
    accounts = Accounts.list_connected_platform_accounts(profile_id)
    running_accounts = Enum.filter(accounts, &(&1.sync_status == "running"))
    failed_accounts = Enum.filter(accounts, &(&1.sync_status == "failed"))

    cond do
      running_accounts != [] ->
        %{
          status: :running,
          title: "Sincronização em andamento",
          message: "Estamos atualizando jogos e troféus agora.",
          progress: true,
          count: length(running_accounts)
        }

      failed_accounts != [] ->
        %{
          status: :failed,
          title: "Sincronização interrompida",
          message: "Algumas contas falharam e podem ser retomadas depois.",
          progress: false,
          count: length(failed_accounts)
        }

      accounts != [] ->
        %{
          status: :idle,
          title: "Sincronização iniciando",
          message: "Preparando atualização de jogos e troféus.",
          progress: true,
          count: length(accounts)
        }

      true ->
        nil
    end
  end

  defp resolve_profile_id_from_conn(conn) do
    case conn.assigns[:current_scope] do
      %Scope{} = scope ->
        case Accounts.get_profile_with_user(scope) do
          %{id: profile_id} when is_integer(profile_id) -> {:ok, profile_id}
          _ -> :error
        end

      _ ->
        case get_session(conn, :profile_id) do
          profile_id when is_integer(profile_id) -> {:ok, profile_id}
          _ -> :error
        end
    end
  end

end
