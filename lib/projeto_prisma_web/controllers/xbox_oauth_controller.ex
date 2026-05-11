defmodule ProjetoPrismaWeb.XboxOAuthController do
  use ProjetoPrismaWeb, :controller
  require Logger

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Sync.Xbox.Auth

  @state_session_key :xbox_oauth_state

  def start(conn, _params) do
    state = :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)

    conn
    |> put_session(@state_session_key, state)
    |> redirect(external: Auth.authorize_url(state))
  end

  def callback(conn, %{"error" => error} = params) do
    description = params["error_description"] || error

    conn
    |> delete_session(@state_session_key)
    |> put_flash(:error, "Falha ao autenticar com a Microsoft: #{description}")
    |> redirect(to: ~p"/connect-platforms")
  end

  def callback(conn, %{"code" => code, "state" => state}) do
    expected_state = get_session(conn, @state_session_key)
    profile_id = current_profile_id(conn)

    cond do
      is_nil(expected_state) or expected_state != state ->
        conn
        |> delete_session(@state_session_key)
        |> put_flash(:error, "Sessão de autenticação Xbox inválida. Tente novamente.")
        |> redirect(to: ~p"/connect-platforms")

      is_nil(profile_id) ->
        conn
        |> delete_session(@state_session_key)
        |> put_flash(:error, "Não foi possível identificar o perfil atual")
        |> redirect(to: ~p"/connect-platforms")

      true ->
        run_oauth_chain(conn, code, profile_id)
    end
  end

  def callback(conn, _params) do
    conn
    |> delete_session(@state_session_key)
    |> put_flash(:error, "Resposta inválida do provedor Microsoft")
    |> redirect(to: ~p"/connect-platforms")
  end

  defp run_oauth_chain(conn, code, profile_id) do
    with {:ok, %{access_token: access, refresh_token: refresh}} when is_binary(refresh) <-
           Auth.exchange_code(code),
         {:ok, %{token: ut}} <- Auth.user_token(access),
         {:ok, %{token: xsts, uhs: uhs, xid: xid, gamertag: gtg}} <- Auth.xsts_token(ut),
         gamertag <- gtg || maybe_fetch_gamertag(xid, uhs, xsts),
         {:ok, _account} <-
           Accounts.connect_platform_account(profile_id, "xbox", %{
             "external_user_id" => xid,
             "profile_url" => profile_url(gamertag),
             "api_key" => refresh
           }) do
      conn
      |> delete_session(@state_session_key)
      |> put_flash(:info, "Conta Xbox vinculada com sucesso" <> gamertag_suffix(gamertag))
      |> redirect(to: ~p"/connect-platforms")
    else
      {:error, {:xsts_xerr, :no_xbox_account, _}} ->
        finish_error(
          conn,
          "Esta conta Microsoft não possui um perfil Xbox Live. Crie um em xbox.com e tente novamente."
        )

      {:error, {:xsts_xerr, :child_account, _}} ->
        finish_error(
          conn,
          "Contas infantis precisam ser adicionadas a um Grupo Familiar antes de conectar."
        )

      {:error, {:xsts_xerr, :country_banned, _}} ->
        finish_error(conn, "Xbox Live não está disponível na região desta conta.")

      {:error, {:xsts_xerr, _other, _body}} ->
        finish_error(conn, "Falha ao autorizar com Xbox Live (XSTS).")

      {:error, {:oauth_http_status, status, body}} ->
        Logger.error("[xbox] OAuth token exchange failed: #{status} #{inspect(body)}")
        desc = (is_map(body) && (body["error_description"] || body["error"])) || ""
        finish_error(conn, "Microsoft #{status}: #{desc}")

      {:error, {:user_token, status, body}} when is_integer(status) ->
        Logger.error("[xbox] User token failed: #{status} #{inspect(body)}")
        finish_error(conn, "Falha ao obter User Token Xbox (status #{status}).")

      {:error, reason} ->
        Logger.error("[xbox] OAuth chain failed: #{inspect(reason)}")
        finish_error(conn, "Não foi possível concluir a vinculação com Xbox Live agora.")

      {:ok, %{refresh_token: nil}} ->
        finish_error(conn, "Microsoft não retornou refresh_token. Verifique a permissão offline_access.")
    end
  end

  defp maybe_fetch_gamertag(xid, uhs, xsts) do
    case Auth.fetch_gamertag(xid, uhs, xsts) do
      {:ok, gt} -> gt
      _ -> nil
    end
  end

  defp profile_url(nil), do: ""
  defp profile_url(gamertag), do: "https://account.xbox.com/profile?gt=#{URI.encode(gamertag)}"

  defp gamertag_suffix(nil), do: ""
  defp gamertag_suffix(gt), do: " (#{gt})"

  defp finish_error(conn, message) do
    conn
    |> delete_session(@state_session_key)
    |> put_flash(:error, message)
    |> redirect(to: ~p"/connect-platforms")
  end

  defp current_profile_id(conn) do
    with %{} = scope <- conn.assigns[:current_scope],
         %{} = profile <- Accounts.get_profile_with_user(scope) do
      profile.id
    else
      _ -> nil
    end
  end
end
