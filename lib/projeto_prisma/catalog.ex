defmodule ProjetoPrisma.Catalog do
  @moduledoc """
  Context para gerenciar games, achievements e plataformas.

  Este módulo encapsula toda a lógica de negócio relacionada a dados
  estáticos de jogos: criar/buscar games, achievements e platform mappings.
  """

  import Ecto.Query
  alias ProjetoPrisma.Repo
  alias ProjetoPrisma.Catalog.{Game, PlatformGame, Achievement}

  @doc """
  Busca ou cria um game.

  ## Parâmetros
    - `attrs` - %{igdb_id: "123", name: "Game Name", cover_image: "..."}

  ## Exemplos
      iex> get_or_create_game(%{igdb_id: "123", name: "Tic Tac Toe"})
      {:ok, %Game{}}
  """
  def get_or_create_game(attrs) do
    igdb_id = attrs["igdb_id"] || attrs[:igdb_id]

    case igdb_id && Repo.get_by(Game, igdb_id: igdb_id) do
      nil ->
        %Game{}
        |> Game.changeset(attrs)
        |> Repo.insert()

      game ->
        {:ok, game}
    end
  end

  @doc """
  Busca ou cria um PlatformGame (junction entre Game e Platform).

  ## Parâmetros
    - `platform_id` - ID da plataforma
    - `game_id` - ID do game
    - `attrs` - %{external_game_id: "203650"}

  ## Exemplos
      iex> get_or_create_platform_game(1, 2, %{external_game_id: "203650"})
      {:ok, %PlatformGame{}}
  """
  def get_or_create_platform_game(platform_id, game_id, attrs) do
    external_game_id = attrs["external_game_id"] || attrs[:external_game_id]

    case Repo.get_by(PlatformGame,
      platform_id: platform_id,
      external_game_id: external_game_id
    ) do
      nil ->
        %PlatformGame{}
        |> PlatformGame.changeset(
          Map.merge(attrs, %{
            "platform_id" => platform_id,
            "game_id" => game_id
          })
        )
        |> Repo.insert()

      platform_game ->
        {:ok, platform_game}
    end
  end

  @doc """
  Busca um PlatformGame pela plataforma e external_game_id.

  ## Exemplos
      iex> get_platform_game_by_external_id(1, "203650")
      %PlatformGame{} | nil
  """
  def get_platform_game_by_external_id(platform_id, external_game_id) do
    Repo.get_by(PlatformGame,
      platform_id: platform_id,
      external_game_id: external_game_id
    )
  end

  @doc """
  Busca ou cria um achievement.

  ## Parâmetros
    - `platform_game_id` - ID do PlatformGame
    - `attrs` - %{external_achievement_id: "...", name: "...", ...}

  ## Exemplos
      iex> get_or_create_achievement(1, %{external_achievement_id: "ach1", name: "First"})
      {:ok, %Achievement{}}
  """
  def get_or_create_achievement(platform_game_id, attrs) do
    external_achievement_id = attrs["external_achievement_id"] || attrs[:external_achievement_id]

    case Repo.get_by(Achievement,
      platform_game_id: platform_game_id,
      external_achievement_id: external_achievement_id
    ) do
      nil ->
        %Achievement{}
        |> Achievement.changeset(
          Map.merge(attrs, %{
            "platform_game_id" => platform_game_id
          })
        )
        |> Repo.insert()

      achievement ->
        {:ok, achievement}
    end
  end

  @doc """
  Lista todos os games de uma plataforma.

  ## Exemplos
      iex> list_platform_games(1)
      [%PlatformGame{}, ...]
  """
  def list_platform_games(platform_id) do
    PlatformGame
    |> where(platform_id: ^platform_id)
    |> preload(:game)
    |> Repo.all()
  end

  @doc """
  Conta quantos achievements um game tem.

  ## Exemplos
      iex> count_achievements(1)
      42
  """
  def count_achievements(platform_game_id) do
    Achievement
    |> where(platform_game_id: ^platform_game_id)
    |> Repo.aggregate(:count, :id)
  end
end
