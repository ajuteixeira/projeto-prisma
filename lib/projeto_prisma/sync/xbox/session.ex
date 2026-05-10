defmodule ProjetoPrisma.Sync.Xbox.Session do
  @moduledoc """
  Materializa o `Authorization: XBL3.0 x=<uhs>;<XSTS>` a partir do refresh
  token armazenado em `profile_platform_accounts.api_key`.

  Cacheia o header em ETS por XUID, com TTL baseado no `NotAfter` do XSTS.
  """

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Sync.Xbox.Auth

  require Logger

  @cache_table :projeto_prisma_xbox_xsts_cache
  @ttl_buffer_seconds 60
  @default_ttl_seconds 14_000

  @doc """
  Retorna `{:ok, %{auth_header, xuid}}` ou `{:error, reason}`.

  `account` precisa ter `:external_user_id` (XUID) e `:api_key` (refresh token).
  Se incluir `:account_id`, refresh tokens rotacionados são persistidos.
  """
  def get_auth(%{external_user_id: xuid, api_key: refresh_token} = account)
      when is_binary(xuid) and is_binary(refresh_token) do
    ensure_cache_table!()

    case cached_header(xuid) do
      {:ok, header} -> {:ok, %{auth_header: header, xuid: xuid}}
      :miss -> derive_and_cache(account)
    end
  end

  @doc """
  Invalida o header em cache para um XUID. Usado quando uma chamada autenticada
  retorna 401 e queremos forçar um novo XSTS na próxima tentativa.
  """
  def invalidate(xuid) when is_binary(xuid) do
    ensure_cache_table!()
    :ets.delete(@cache_table, xuid)
    :ok
  end

  defp derive_and_cache(%{external_user_id: xuid, api_key: refresh_token} = account) do
    with {:ok, %{access_token: access, refresh_token: new_refresh}} <- Auth.refresh(refresh_token),
         :ok <- maybe_persist_refresh(account, refresh_token, new_refresh),
         {:ok, %{token: ut}} <- Auth.user_token(access),
         {:ok, %{token: xsts, uhs: uhs, not_after: not_after}} <- Auth.xsts_token(ut) do
      header = Auth.auth_header(uhs, xsts)
      expires_at = expires_at_from(not_after)
      :ets.insert(@cache_table, {xuid, header, expires_at})
      {:ok, %{auth_header: header, xuid: xuid}}
    else
      {:error, {:oauth_http_status, status, %{"error" => "invalid_grant"}}} when status in 400..499 ->
        {:error, :xbox_reconnect_required}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_persist_refresh(%{account_id: account_id}, old, new)
       when is_integer(account_id) and is_binary(new) and new != old do
    case Accounts.update_platform_credential(account_id, %{"api_key" => new}) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("[xbox] failed to persist rotated refresh token: #{inspect(reason)}")
        :ok
    end
  end

  defp maybe_persist_refresh(_, _, _), do: :ok

  defp cached_header(xuid) do
    case :ets.lookup(@cache_table, xuid) do
      [{^xuid, header, expires_at}] ->
        if DateTime.to_unix(DateTime.utc_now()) < expires_at do
          {:ok, header}
        else
          :ets.delete(@cache_table, xuid)
          :miss
        end

      [] ->
        :miss
    end
  end

  defp expires_at_from(nil), do: DateTime.to_unix(DateTime.utc_now()) + @default_ttl_seconds

  defp expires_at_from(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> DateTime.to_unix(dt) - @ttl_buffer_seconds
      _ -> DateTime.to_unix(DateTime.utc_now()) + @default_ttl_seconds
    end
  end

  defp ensure_cache_table! do
    case :ets.whereis(@cache_table) do
      :undefined ->
        try do
          :ets.new(@cache_table, [:named_table, :public, :set, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _ ->
        :ok
    end
  end
end
