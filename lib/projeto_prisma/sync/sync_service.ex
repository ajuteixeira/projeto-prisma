defmodule ProjetoPrisma.Sync.SyncService do
  @moduledoc """
  Serviço de orquestração para sincronizar dados de plataformas.

  Coordena o fluxo completo:
  1. Busca dados do adapter (Steam, PlayStation, etc)
  2. Persiste games e achievements via Catalog
  3. Persiste dados de usuário via Accounts
  """

  alias ProjetoPrisma.{Catalog, Accounts, Repo}
  alias ProjetoPrisma.Sync.Adapters
  alias ProjetoPrisma.Sync.Igdb.Adapter, as: IgdbAdapter

  require Logger
  @stale_sync_after_seconds 300

  @doc """
  Sincroniza games e achievements de um usuário em uma plataforma.

  ## Parâmetros
    - `profile_id` - ID do perfil do usuário
    - `platform_slug` - "steam", "playstation", "xbox"
    - `external_user_id` - ID do usuário na plataforma
    - `api_key` - Chave API da plataforma

  ## Exemplos
      iex> sync_profile(1, :steam, "76561198310494902", "API_KEY")
      {:ok, %{games_synced: 5, achievements_synced: 42}}
  """
  def sync_profile(profile_id, platform_slug, external_user_id, api_key) do
    with :ok <- validate_profile(profile_id),
         {:ok, platform} <- get_platform(platform_slug),
         {:ok, adapter} <- get_adapter(platform_slug),
         {:ok, ppa} <-
           create_profile_platform_account(profile_id, platform.id, external_user_id, api_key),
         {:ok, stats} <-
           sync_games_and_achievements(
             profile_id,
             platform.id,
             platform.slug,
             adapter,
             external_user_id,
             api_key,
             ppa.id
           ) do
      {:ok, stats}
    else
      error -> error
    end
  end

  @doc """
  Sincroniza todas as contas de plataforma conectadas de um profile.
  """
  def sync_connected_platforms(profile_id) do
    with :ok <- validate_profile(profile_id) do
      profile_platform_accounts =
        profile_id
        |> Accounts.list_connected_platform_accounts()
        |> Enum.filter(&syncable_platform_account?/1)

      # Broadcast that the sync started for this profile
      broadcast(profile_id, %{type: "sync:start", total: length(profile_platform_accounts)})

      summary =
        Enum.reduce(profile_platform_accounts, base_summary(), fn account, acc ->
          case Accounts.mark_platform_sync_started(account, "sync_profile") do
            {:ok, running_account} ->
              # Broadcast account start
              broadcast(profile_id, %{
                type: "account:start",
                account_id: running_account.id,
                platform: running_account.platform.slug
              })

              case safe_sync_profile(
                     profile_id,
                     running_account.platform.slug,
                     running_account.external_user_id,
                     running_account.api_key
                   ) do
                {:ok, %{games_synced: games_synced, achievements_synced: achievements_synced}} ->
                  _ = Accounts.mark_platform_sync_finished(running_account, "sync_profile")

                  # Broadcast account finished
                  broadcast(profile_id, %{
                    type: "account:finished",
                    account_id: running_account.id,
                    games_synced: games_synced,
                    achievements_synced: achievements_synced
                  })

                  %{
                    acc
                    | synced: acc.synced + 1,
                      games_synced: acc.games_synced + games_synced,
                      achievements_synced: acc.achievements_synced + achievements_synced
                  }

                {:error, reason} ->
                  _ = Accounts.mark_platform_sync_failed(running_account, "sync_profile", reason)

                  # Broadcast account failed
                  broadcast(profile_id, %{
                    type: "account:failed",
                    account_id: running_account.id,
                    reason: inspect(reason)
                  })

                  %{acc | failed: acc.failed + 1}
              end

            {:error, _reason} ->
              %{acc | failed: acc.failed + 1}
          end
        end)

      # Broadcast sync finished summary
      broadcast(profile_id, Map.put(summary, :type, "sync:finished"))

      {:ok, summary}
    end
  end

  defp safe_sync_profile(profile_id, platform_slug, external_user_id, api_key) do
    sync_profile(profile_id, platform_slug, external_user_id, api_key)
  rescue
    exception ->
      stacktrace = __STACKTRACE__

      Logger.error("""
      Sync crashed for profile #{profile_id} on #{platform_slug}:
      #{Exception.format(:error, exception, stacktrace)}
      """)

      {:error, {:exception, exception.__struct__, Exception.message(exception)}}
  catch
    kind, reason ->
      Logger.error("""
      Sync exited for profile #{profile_id} on #{platform_slug}:
      #{Exception.format(kind, reason, __STACKTRACE__)}
      """)

      {:error, {kind, reason}}
  end

  defp base_summary do
    %{synced: 0, failed: 0, games_synced: 0, achievements_synced: 0}
  end

  defp syncable_platform_account?(%{sync_status: status}) when status in [nil, "idle"], do: true

  defp syncable_platform_account?(%{
         sync_status: "running",
         sync_started_at: %NaiveDateTime{} = started_at
       }) do
    NaiveDateTime.diff(NaiveDateTime.utc_now(), started_at, :second) >= @stale_sync_after_seconds
  end

  defp syncable_platform_account?(_account), do: false

  # Valida que o profile existe
  defp validate_profile(profile_id) do
    case Accounts.get_profile(profile_id) do
      nil -> {:error, :profile_not_found}
      _profile -> :ok
    end
  end

  # Helper para broadcast via Phoenix.PubSub
  defp broadcast(profile_id, payload) do
    topic = "sync:profile:" <> to_string(profile_id)
    Phoenix.PubSub.broadcast(ProjetoPrisma.PubSub, topic, {:sync_event, payload})
  end

  # Busca a plataforma
  defp get_platform(platform_slug) do
    slug = platform_slug_to_string(platform_slug)

    case Repo.get_by(Catalog.Platform, slug: slug) do
      nil -> {:error, :platform_not_found}
      platform -> {:ok, platform}
    end
  end

  # Retorna o adapter
  defp get_adapter(platform_slug) do
    case normalize_platform_slug(platform_slug) do
      {:ok, slug} ->
        case Adapters.get_adapter(slug) do
          {:error, _} = err -> err
          adapter -> {:ok, adapter}
        end

      {:error, _} = err ->
        err
    end
  end

  defp normalize_platform_slug(slug)
       when is_atom(slug) and slug in [:steam, :playstation, :xbox, :retroachievements],
       do: {:ok, slug}

  defp normalize_platform_slug(slug) when is_binary(slug) do
    case slug do
      "steam" -> {:ok, :steam}
      "playstation" -> {:ok, :playstation}
      "xbox" -> {:ok, :xbox}
      "retroachievements" -> {:ok, :retroachievements}
      _ -> {:error, "Plataforma #{slug} não suportada"}
    end
  end

  defp normalize_platform_slug(slug), do: {:error, "Plataforma #{inspect(slug)} não suportada"}

  # Converte platform_slug para string
  defp platform_slug_to_string(slug) when is_atom(slug) do
    Atom.to_string(slug)
  end

  defp platform_slug_to_string(slug) when is_binary(slug) do
    slug
  end

  # Cria ou busca conta de plataforma do usuário
  defp create_profile_platform_account(profile_id, platform_id, external_user_id, api_key) do
    Accounts.get_or_create_platform_account(profile_id, platform_id, %{
      "external_user_id" => external_user_id,
      "api_key" => api_key
    })
  end

  # Sincroniza todos os games e achievements
  defp sync_games_and_achievements(
         profile_id,
         platform_id,
         platform_slug,
         adapter,
         external_user_id,
         api_key,
         account_id
       ) do
    account = %{
      external_user_id: external_user_id,
      api_key: api_key,
      account_id: account_id
    }

    # Tenta com backoff exponencial (1s, 2s, 4s)
    case retry_with_backoff(fn -> adapter.fetch_games(account) end, 3) do
      {:ok, games} ->
        # Emite o total de jogos a sincronizar para essa plataforma
        broadcast(profile_id, %{
          type: "games:total",
          total_games: length(games),
          platform_id: platform_id
        })

        stats = sync_all_games(profile_id, platform_id, platform_slug, adapter, account, games)
        {:ok, stats}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Retry com backoff exponencial
  defp retry_with_backoff(func, attempts, attempt \\ 1) do
    case func.() do
      {:ok, result} ->
        {:ok, result}

      {:error, _reason} when attempt < attempts ->
        wait_time = :math.pow(2, attempt - 1) |> trunc() |> max(1)
        Process.sleep(wait_time * 1000)
        retry_with_backoff(func, attempts, attempt + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Sincroniza cada game
  defp sync_all_games(profile_id, platform_id, platform_slug, adapter, account, games) do
    total_games = length(games)
    games_synced = 0
    achievements_synced = 0

    Enum.reduce(games, {games_synced, achievements_synced, 0}, fn
      game, {g_count, a_count, game_index} ->
        current_index = game_index + 1

        case sync_single_game(profile_id, platform_id, platform_slug, adapter, account, game) do
          {:ok, achievements_count} ->
            # Emite progresso: X de Y jogos processados
            progress_percent = round(current_index / total_games * 100)

            broadcast(profile_id, %{
              type: "game:synced",
              current: current_index,
              total: total_games,
              progress_percent: progress_percent,
              achievements_count: achievements_count
            })

            {g_count + 1, a_count + achievements_count, current_index}

          {:error, _reason} ->
            progress_percent = round(current_index / total_games * 100)

            broadcast(profile_id, %{
              type: "game:failed",
              current: current_index,
              total: total_games,
              progress_percent: progress_percent
            })

            {g_count, a_count, current_index}
        end
    end)
    |> (fn {g, a, _} -> build_response({g, a}) end).()
  end

  # Sincroniza um game específico e seus achievements
  defp sync_single_game(profile_id, platform_id, platform_slug, adapter, account, game_data) do
    external_game_id = game_value(game_data, :external_game_id)

    with {:ok, igdb_game} <- IgdbAdapter.enrich_game(game_data, platform_slug),
         {:ok, game} <- Catalog.get_or_create_game(igdb_game),
         {:ok, platform_game} <-
           Catalog.get_or_create_platform_game(
             platform_id,
             game.id,
             %{"external_game_id" => external_game_id}
           ),
         {:ok, profile_game} <-
           Accounts.get_or_create_profile_game(
             profile_id,
             platform_game.id,
             %{
               "playtime_minutes" => game_value(game_data, :playtime_minutes) || 0,
               "last_played" =>
                 game_value(game_data, :last_played) ||
                   (DateTime.utc_now() |> DateTime.to_naive())
             }
           ) do
      achievements_count =
        sync_game_achievements(
          adapter,
          account,
          achievement_game_ref(game_data, external_game_id),
          profile_game.id,
          platform_game.id
        )

      {:ok, achievements_count}
    else
      error -> error
    end
  end

  defp sync_game_achievements(
         adapter,
         account,
         external_game_id,
         profile_game_id,
         platform_game_id
       ) do
    case adapter.fetch_achievements(account, external_game_id) do
      {:ok, achievements} ->
        sync_achievements(profile_game_id, platform_game_id, achievements)

      {:error, reason} ->
        Logger.warning(
          "Skipping achievements for external game #{external_game_id}: #{inspect(reason)}"
        )

        0
    end
  end

  defp game_value(game_data, key) when is_map(game_data) do
    Map.get(game_data, key) || Map.get(game_data, Atom.to_string(key))
  end

  defp achievement_game_ref(game_data, external_game_id) do
    case game_value(game_data, :np_service_name) do
      nil -> external_game_id
      "" -> external_game_id
      np_service_name -> %{external_game_id: external_game_id, np_service_name: np_service_name}
    end
  end

  # Sincroniza achievements de um game
  defp sync_achievements(profile_game_id, platform_game_id, achievements) do
    Enum.reduce(achievements, 0, fn ach_data, count ->
      case Catalog.get_or_create_achievement(platform_game_id, ach_data) do
        {:ok, achievement} ->
          Accounts.get_or_create_profile_achievement(
            profile_game_id,
            achievement.id,
            %{
              "achieved" => achievement_value(ach_data, :achieved) || false,
              "unlock_time" => achievement_value(ach_data, :unlock_time)
            }
          )

          count + 1

        {:error, _reason} ->
          count
      end
    end)
  end

  defp achievement_value(achievement_data, key) when is_map(achievement_data) do
    Map.get(achievement_data, key) || Map.get(achievement_data, Atom.to_string(key))
  end

  # Constrói resposta com estatísticas
  defp build_response({games_synced, achievements_synced}) do
    %{
      games_synced: games_synced,
      achievements_synced: achievements_synced
    }
  end
end
