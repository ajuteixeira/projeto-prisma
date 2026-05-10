defmodule ProjetoPrisma.Sync.Xbox.Auth do
  @moduledoc """
  Cliente de autenticação Xbox Live (Microsoft OAuth + XSTS).

  Fluxo:
    1. authorize_url/1     -> URL de consentimento Microsoft
    2. exchange_code/1     -> code -> %{access_token, refresh_token}
    3. refresh/1           -> refresh_token -> novos tokens
    4. user_token/1        -> access_token -> Xbox User Token
    5. xsts_token/1        -> User Token -> XSTS Token (+ uhs, xid)
    6. auth_header/2       -> "XBL3.0 x=<uhs>;<xsts_token>"
    7. fetch_gamertag/3    -> chama profile.xboxlive.com com o header montado
  """

  @authorize_url "https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize"
  @token_url "https://login.microsoftonline.com/consumers/oauth2/v2.0/token"
  @user_auth_url "https://user.auth.xboxlive.com/user/authenticate"
  @xsts_authorize_url "https://xsts.auth.xboxlive.com/xsts/authorize"
  @profile_url "https://profile.xboxlive.com/users/xuid"

  @scope "XboxLive.signin offline_access"

  @doc "Monta a URL de autorização Microsoft com state CSRF."
  def authorize_url(state) when is_binary(state) do
    query =
      URI.encode_query(%{
        "client_id" => client_id(),
        "response_type" => "code",
        "response_mode" => "query",
        "scope" => @scope,
        "redirect_uri" => redirect_uri(),
        "state" => state
      })

    "#{@authorize_url}?#{query}"
  end

  @doc "Troca o code da Microsoft por access_token + refresh_token."
  def exchange_code(code) when is_binary(code) do
    Req.post(@token_url,
      form: [
        client_id: client_id(),
        client_secret: client_secret(),
        code: code,
        grant_type: "authorization_code",
        redirect_uri: redirect_uri(),
        scope: @scope
      ]
    )
    |> handle_oauth_response()
  end

  @doc "Renova access_token usando refresh_token (refresh pode ser rotacionado)."
  def refresh(refresh_token) when is_binary(refresh_token) do
    Req.post(@token_url,
      form: [
        client_id: client_id(),
        client_secret: client_secret(),
        refresh_token: refresh_token,
        grant_type: "refresh_token",
        redirect_uri: redirect_uri(),
        scope: @scope
      ]
    )
    |> handle_oauth_response()
  end

  defp handle_oauth_response({:ok, %{status: 200, body: body}}) when is_map(body) do
    {:ok,
     %{
       access_token: body["access_token"],
       refresh_token: body["refresh_token"],
       expires_in: body["expires_in"]
     }}
  end

  defp handle_oauth_response({:ok, %{status: status, body: body}}) do
    {:error, {:oauth_http_status, status, body}}
  end

  defp handle_oauth_response({:error, reason}), do: {:error, {:oauth_request_failed, reason}}

  @doc "Troca access_token Microsoft pelo Xbox User Token."
  def user_token(access_token) when is_binary(access_token) do
    body = %{
      "Properties" => %{
        "AuthMethod" => "RPS",
        "SiteName" => "user.auth.xboxlive.com",
        "RpsTicket" => "d=" <> access_token
      },
      "RelyingParty" => "http://auth.xboxlive.com",
      "TokenType" => "JWT"
    }

    Req.post(@user_auth_url,
      headers: [
        {"Content-Type", "application/json"},
        {"Accept", "application/json"},
        {"x-xbl-contract-version", "1"}
      ],
      json: body
    )
    |> handle_token_response(:user_token)
  end

  @doc "Troca o User Token pelo XSTS token (Token + uhs + xid)."
  def xsts_token(user_token) when is_binary(user_token) do
    body = %{
      "Properties" => %{
        "SandboxId" => "RETAIL",
        "UserTokens" => [user_token]
      },
      "RelyingParty" => "http://xboxlive.com",
      "TokenType" => "JWT"
    }

    Req.post(@xsts_authorize_url,
      headers: [
        {"Content-Type", "application/json"},
        {"Accept", "application/json"},
        {"x-xbl-contract-version", "1"}
      ],
      json: body
    )
    |> handle_xsts_response()
  end

  defp handle_token_response({:ok, %{status: status, body: body}}, _kind)
       when status in 200..299 and is_map(body) do
    {:ok, %{token: body["Token"], not_after: body["NotAfter"]}}
  end

  defp handle_token_response({:ok, %{status: status, body: body}}, kind) do
    {:error, {kind, status, body}}
  end

  defp handle_token_response({:error, reason}, kind), do: {:error, {kind, reason}}

  defp handle_xsts_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    xui = get_in(body, ["DisplayClaims", "xui"]) |> List.wrap() |> List.first() || %{}

    {:ok,
     %{
       token: body["Token"],
       not_after: body["NotAfter"],
       uhs: xui["uhs"],
       xid: xui["xid"],
       gamertag: xui["gtg"]
     }}
  end

  defp handle_xsts_response({:ok, %{status: 401, body: %{"XErr" => xerr} = body}}) do
    {:error, {:xsts_xerr, xerr_to_atom(xerr), body}}
  end

  defp handle_xsts_response({:ok, %{status: status, body: body}}) do
    {:error, {:xsts_http_status, status, body}}
  end

  defp handle_xsts_response({:error, reason}), do: {:error, {:xsts_request_failed, reason}}

  defp xerr_to_atom(2_148_916_233), do: :no_xbox_account
  defp xerr_to_atom(2_148_916_235), do: :country_banned
  defp xerr_to_atom(2_148_916_236), do: :age_verification_required
  defp xerr_to_atom(2_148_916_237), do: :age_verification_required
  defp xerr_to_atom(2_148_916_238), do: :child_account
  defp xerr_to_atom(_), do: :unknown_xerr

  @doc "Authorization header para chamadas autenticadas Xbox Live."
  def auth_header(uhs, xsts_token) when is_binary(uhs) and is_binary(xsts_token) do
    "XBL3.0 x=#{uhs};#{xsts_token}"
  end

  @doc """
  Busca a gamertag para um XUID usando um header XBL3.0 já montado.
  Retorna {:ok, gamertag} ou {:error, reason}.
  """
  def fetch_gamertag(xuid, uhs, xsts_token) do
    Req.get("#{@profile_url}(#{xuid})/profile/settings",
      params: [settings: "Gamertag"],
      headers: [
        {"Authorization", auth_header(uhs, xsts_token)},
        {"x-xbl-contract-version", "3"},
        {"Accept", "application/json"}
      ]
    )
    |> case do
      {:ok, %{status: 200, body: body}} ->
        gamertag =
          body
          |> get_in(["profileUsers", Access.at(0), "settings"])
          |> List.wrap()
          |> Enum.find_value(fn s ->
            if s["id"] == "Gamertag", do: s["value"]
          end)

        if gamertag, do: {:ok, gamertag}, else: {:error, :gamertag_not_found}

      {:ok, %{status: status, body: body}} ->
        {:error, {:profile_http_status, status, body}}

      {:error, reason} ->
        {:error, {:profile_request_failed, reason}}
    end
  end

  defp client_id, do: System.fetch_env!("XBOX_CLIENT_ID")
  defp client_secret, do: System.fetch_env!("XBOX_CLIENT_SECRET")
  defp redirect_uri, do: System.fetch_env!("XBOX_REDIRECT_URI")
end
