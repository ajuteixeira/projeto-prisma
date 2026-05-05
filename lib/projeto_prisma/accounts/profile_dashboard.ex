defmodule ProjetoPrisma.Accounts.ProfileDashboard do
  @moduledoc """
  Consultas de leitura para compor a dashboard do perfil.
  """

  import Ecto.Query

  alias ProjetoPrisma.Accounts.{Profile, ProfileAchievement, ProfileGame}
  alias ProjetoPrisma.Catalog.{Achievement, Platform}
  alias ProjetoPrisma.Repo

  @doc """
  Busca o profile do usuario logado com user e avatar preloads.
  """
  def profile_for_user(user_id) when is_integer(user_id) do
    Profile
    |> where([p], p.user_id == ^user_id)
    |> preload([:user, :avatar])
    |> Repo.one()
  end

  def profile_for_user(_), do: nil

  @doc """
  Retorna o jogo jogado mais recentemente com metricas agregadas.
  """
  def recently_played(profile_id) when is_integer(profile_id) do
    profile_id
    |> list_games(1, sort_order: :desc)
    |> List.first()
    |> maybe_put_recent_achievements()
  end

  def recently_played(_), do: nil

  @doc """
  Retorna os detalhes de um jogo do profile com suas conquistas.
  """
  def game_details(profile_id, profile_game_id)
      when is_integer(profile_id) and is_integer(profile_game_id) do
    profile_id
    |> games_with_metrics(profile_game_id: profile_game_id)
    |> List.first()
    |> maybe_put_game_achievements()
  end

  def game_details(_, _), do: nil

  @doc """
  Lista jogos recentes com metricas para tabela.
  """
  def list_games(profile_id, limit \\ 10, opts \\ [])

  def list_games(profile_id, limit, opts)
      when is_integer(profile_id) and is_integer(limit) and is_list(opts) do
    games_with_metrics(
      profile_id,
      limit: limit,
      offset: Keyword.get(opts, :offset, 0),
      sort_order: Keyword.get(opts, :sort_order, :desc),
      search_query: Keyword.get(opts, :search_query, "")
    )
  end

  def list_games(_, _, _), do: []

  @doc """
  Retorna cards de estatisticas gerais do perfil.
  """
  def stats(profile_id) when is_integer(profile_id) do
    games = games_with_metrics(profile_id)

    total_achievements =
      ProfileAchievement
      |> join(:inner, [pa], pg in ProfileGame, on: pg.id == pa.profile_game_id)
      |> where([pa, pg], pg.profile_id == ^profile_id and pa.achieved == true)
      |> select([pa, _pg], count(pa.id))
      |> Repo.one()
      |> Kernel.||(0)

    {completion_sum, completion_count, perfect_games} =
      Enum.reduce(games, {0.0, 0, 0}, fn game, {sum, count_games, perfect} ->
        cond do
          game.total_achievements > 0 ->
            completion = game.unlocked_achievements * 100 / game.total_achievements
            is_perfect = if game.unlocked_achievements >= game.total_achievements, do: 1, else: 0
            {sum + completion, count_games + 1, perfect + is_perfect}

          true ->
            {sum, count_games, perfect}
        end
      end)

    avg_completion =
      if completion_count == 0 do
        0
      else
        Float.round(completion_sum / completion_count, 1)
      end

    %{
      total_achievements: total_achievements,
      avg_completion: avg_completion,
      perfect_games: perfect_games
    }
  end

  def stats(_), do: %{total_achievements: 0, avg_completion: 0, perfect_games: 0}

  @doc """
  Distribuicao de conquistas desbloqueadas por plataforma.
  """
  def platform_distribution(profile_id) when is_integer(profile_id) do
    unlocked_by_platform =
      ProfileAchievement
      |> join(:inner, [pa], pg in ProfileGame, on: pg.id == pa.profile_game_id)
      |> join(:inner, [_pa, pg], pgame in assoc(pg, :platform_game))
      |> where([pa, pg, _pgame], pg.profile_id == ^profile_id and pa.achieved == true)
      |> group_by([_pa, _pg, pgame], pgame.platform_id)
      |> select([_pa, _pg, pgame], {pgame.platform_id, count()})
      |> Repo.all()
      |> Map.new()

    platforms =
      Platform
      |> order_by([p], asc: p.id)
      |> Repo.all()

    total = unlocked_by_platform |> Map.values() |> Enum.sum()

    Enum.map(platforms, fn platform ->
      unlocked = Map.get(unlocked_by_platform, platform.id, 0)

      percentage =
        if total == 0 do
          0
        else
          Float.round(unlocked * 100 / total, 1)
        end

      %{
        platform_id: platform.id,
        name: platform.name,
        slug: platform.slug,
        unlocked: unlocked,
        percentage: percentage
      }
    end)
  end

  def platform_distribution(_), do: []

  defp maybe_put_recent_achievements(nil), do: nil

  defp maybe_put_recent_achievements(game) do
    achievements =
      ProfileAchievement
      |> join(:inner, [pa], a in Achievement, on: a.id == pa.achievement_id)
      |> where([pa, _a], pa.profile_game_id == ^game.profile_game_id and pa.achieved == true)
      |> order_by([pa, _a], desc: pa.unlock_time)
      |> limit(5)
      |> select([_pa, a], %{name: a.name, icon: a.icon_image})
      |> Repo.all()

    Map.put(game, :recent_achievements, achievements)
  end

  defp maybe_put_game_achievements(nil), do: nil

  defp maybe_put_game_achievements(game) do
    achievements =
      Achievement
      |> where([a], a.platform_game_id == ^game.platform_game_id)
      |> join(:left, [a], pa in ProfileAchievement,
        on: pa.achievement_id == a.id and pa.profile_game_id == ^game.profile_game_id
      )
      |> order_by(
        [a, pa],
        desc: fragment("COALESCE(?, false)", pa.achieved),
        desc_nulls_last: pa.unlock_time,
        asc: a.name
      )
      |> select([a, pa], %{
        name: a.name,
        description: a.description,
        icon_image: a.icon_image,
        icon_locked_image: a.icon_locked_image,
        achieved: type(fragment("COALESCE(?, false)", pa.achieved), :boolean),
        unlock_time: pa.unlock_time
      })
      |> Repo.all()

    Map.put(game, :achievements, achievements)
  end

  defp games_with_metrics(profile_id, opts \\ []) do
    limit = Keyword.get(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)
    sort_order = Keyword.get(opts, :sort_order, :desc)
    profile_game_id = Keyword.get(opts, :profile_game_id)
    search_query = normalize_search_query(Keyword.get(opts, :search_query, ""))

    base_query =
      ProfileGame
      |> where([pg], pg.profile_id == ^profile_id)
      |> join(:inner, [pg], pgame in assoc(pg, :platform_game))
      |> join(:inner, [_pg, pgame], g in assoc(pgame, :game))
      |> join(:inner, [_pg, pgame, _g], p in assoc(pgame, :platform))
      |> maybe_filter_by_profile_game_id(profile_game_id)
      |> maybe_filter_by_game_name(search_query)
      |> sort_by_last_played(sort_order)
      |> select([pg, pgame, g, p], %{
        profile_game_id: pg.id,
        platform_game_id: pgame.id,
        game_name: g.name,
        game_cover_image: g.cover_image,
        game_icon_image: g.icon_image,
        playtime_minutes: pg.playtime_minutes,
        last_played: pg.last_played,
        platform_name: p.name,
        platform_slug: p.slug
      })
      |> maybe_offset(offset)

    base_games =
      if is_integer(limit) and limit > 0 do
        base_query |> limit(^limit) |> Repo.all()
      else
        Repo.all(base_query)
      end

    profile_game_ids = Enum.map(base_games, & &1.profile_game_id)
    platform_game_ids = Enum.map(base_games, & &1.platform_game_id)

    unlocked_map = unlocked_counts_by_profile_game(profile_game_ids)
    total_map = total_counts_by_platform_game(platform_game_ids)
    last_unlock_map = last_unlock_by_profile_game(profile_game_ids)

    Enum.map(base_games, fn game ->
      unlocked = Map.get(unlocked_map, game.profile_game_id, 0)
      total = Map.get(total_map, game.platform_game_id, 0)

      completion =
        if total == 0 do
          0.0
        else
          Float.round(unlocked * 100 / total, 1)
        end

      game
      |> Map.put(:unlocked_achievements, unlocked)
      |> Map.put(:total_achievements, total)
      |> Map.put(:completion_percent, completion)
      |> Map.put(:last_unlock_time, Map.get(last_unlock_map, game.profile_game_id))
    end)
  end

  defp maybe_offset(query, offset) when is_integer(offset) and offset > 0 do
    offset(query, ^offset)
  end

  defp maybe_offset(query, _offset), do: query

  defp maybe_filter_by_profile_game_id(query, profile_game_id) when is_integer(profile_game_id) do
    where(query, [pg, _pgame, _g, _p], pg.id == ^profile_game_id)
  end

  defp maybe_filter_by_profile_game_id(query, _profile_game_id), do: query

  defp maybe_filter_by_game_name(query, ""), do: query

  defp maybe_filter_by_game_name(query, search_query) do
    where(query, [_pg, _pgame, g, _p], ilike(g.name, ^"%#{search_query}%"))
  end

  defp sort_by_last_played(query, :asc) do
    order_by(query, [pg, _pgame, _g, _p], asc_nulls_last: pg.last_played, asc: pg.id)
  end

  defp sort_by_last_played(query, _sort_order) do
    order_by(query, [pg, _pgame, _g, _p], desc_nulls_last: pg.last_played, desc: pg.id)
  end

  defp normalize_search_query(search_query) when is_binary(search_query) do
    search_query
    |> String.trim()
  end

  defp normalize_search_query(_search_query), do: ""

  defp unlocked_counts_by_profile_game([]), do: %{}

  defp unlocked_counts_by_profile_game(profile_game_ids) do
    ProfileAchievement
    |> where([pa], pa.profile_game_id in ^profile_game_ids and pa.achieved == true)
    |> group_by([pa], pa.profile_game_id)
    |> select([pa], {pa.profile_game_id, count(pa.id)})
    |> Repo.all()
    |> Map.new()
  end

  defp total_counts_by_platform_game([]), do: %{}

  defp total_counts_by_platform_game(platform_game_ids) do
    Achievement
    |> where([a], a.platform_game_id in ^platform_game_ids)
    |> group_by([a], a.platform_game_id)
    |> select([a], {a.platform_game_id, count(a.id)})
    |> Repo.all()
    |> Map.new()
  end

  defp last_unlock_by_profile_game([]), do: %{}

  defp last_unlock_by_profile_game(profile_game_ids) do
    ProfileAchievement
    |> where([pa], pa.profile_game_id in ^profile_game_ids and pa.achieved == true)
    |> group_by([pa], pa.profile_game_id)
    |> select([pa], {pa.profile_game_id, max(pa.unlock_time)})
    |> Repo.all()
    |> Map.new()
  end
end
