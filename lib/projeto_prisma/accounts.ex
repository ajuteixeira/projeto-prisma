defmodule ProjetoPrisma.Accounts do
  @moduledoc """
  Context para gerenciar profiles de usuários e suas contas em plataformas.

  Encapsula lógica de criar/buscar profiles, contas de plataforma,
  e games/achievements sincronizados do usuário.
  """

  import Ecto.Query
  alias ProjetoPrisma.Repo
  alias ProjetoPrisma.Accounts.{Profile, ProfilePlatformAccount, ProfileGame, ProfileAchievement}

  @doc """
  Busca ou cria um profile.

  ## Parâmetros
    - `attrs` - %{username: "john_doe"}

  ## Exemplos
      iex> get_or_create_profile(%{username: "john_doe"})
      {:ok, %Profile{}}
  """
  def get_or_create_profile(attrs) do
    username = attrs["username"] || attrs[:username]

    case Repo.get_by(Profile, username: username) do
      nil ->
        %Profile{}
        |> Profile.changeset(attrs)
        |> Repo.insert()

      profile ->
        {:ok, profile}
    end
  end

  @doc """
  Busca um profile pelo ID.

  ## Exemplos
      iex> get_profile(1)
      %Profile{} | nil
  """
  def get_profile(profile_id) do
    Repo.get(Profile, profile_id)
  end

  @doc """
  Busca ou cria uma conta de usuário em uma plataforma.

  ## Parâmetros
    - `profile_id` - ID do perfil
    - `platform_id` - ID da plataforma
    - `attrs` - %{external_user_id: "76561198310494902", profile_url: "..."}

  ## Exemplos
      iex> get_or_create_platform_account(1, 1, %{external_user_id: "12345", profile_url: "..."})
      {:ok, %ProfilePlatformAccount{}}
  """
  def get_or_create_platform_account(profile_id, platform_id, attrs) do
    case Repo.get_by(ProfilePlatformAccount,
      profile_id: profile_id,
      platform_id: platform_id
    ) do
      nil ->
        %ProfilePlatformAccount{}
        |> ProfilePlatformAccount.changeset(
          Map.merge(attrs, %{
            "profile_id" => profile_id,
            "platform_id" => platform_id
          })
        )
        |> Repo.insert()

      account ->
        {:ok, account}
    end
  end

  @doc """
  Busca uma conta de plataforma de um usuário.

  ## Exemplos
      iex> get_platform_account(profile_id, platform_id)
      %ProfilePlatformAccount{} | nil
  """
  def get_platform_account(profile_id, platform_id) do
    Repo.get_by(ProfilePlatformAccount,
      profile_id: profile_id,
      platform_id: platform_id
    )
  end

  @doc """
  Busca ou cria um game na biblioteca do usuário.

  ## Parâmetros
    - `profile_id` - ID do perfil
    - `platform_game_id` - ID do PlatformGame
    - `attrs` - %{playtime_minutes: 100, last_played: NaiveDateTime}

  ## Exemplos
      iex> get_or_create_profile_game(1, 1, %{playtime_minutes: 100, last_played: ~N[2025-03-15 10:00:00]})
      {:ok, %ProfileGame{}}
  """
  def get_or_create_profile_game(profile_id, platform_game_id, attrs) do
    case Repo.get_by(ProfileGame,
      profile_id: profile_id,
      platform_game_id: platform_game_id
    ) do
      nil ->
        %ProfileGame{}
        |> ProfileGame.changeset(
          Map.merge(attrs, %{
            "profile_id" => profile_id,
            "platform_game_id" => platform_game_id
          })
        )
        |> Repo.insert()

      profile_game ->
        # Se já existe, atualiza com novos dados
        profile_game
        |> ProfileGame.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Busca ou cria um achievement desbloqueado pelo usuário.

  ## Parâmetros
    - `profile_game_id` - ID do ProfileGame
    - `achievement_id` - ID do Achievement
    - `attrs` - %{achieved: true, unlock_time: NaiveDateTime}

  ## Exemplos
      iex> get_or_create_profile_achievement(1, 1, %{achieved: true, unlock_time: ~N[2025-03-15 10:00:00]})
      {:ok, %ProfileAchievement{}}
  """
  def get_or_create_profile_achievement(profile_game_id, achievement_id, attrs) do
    case Repo.get_by(ProfileAchievement,
      profile_game_id: profile_game_id,
      achievement_id: achievement_id
    ) do
      nil ->
        %ProfileAchievement{}
        |> ProfileAchievement.changeset(
          Map.merge(attrs, %{
            "profile_game_id" => profile_game_id,
            "achievement_id" => achievement_id
          })
        )
        |> Repo.insert()

      profile_achievement ->
        # Se já existe, atualiza (caso tenha desbloqueado agora)
        profile_achievement
        |> ProfileAchievement.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Lista todos os games de um usuário em uma plataforma.

  ## Exemplos
      iex> list_user_games(1, 1)
      [%ProfileGame{}, ...]
  """
  def list_user_games(profile_id, platform_id) do
    ProfileGame
    |> where([pg], pg.profile_id == ^profile_id)
    |> preload(:platform_game)
    |> Repo.all()
    |> Enum.filter(fn pg -> pg.platform_game.platform_id == platform_id end)
  end

  @doc """
  Conta quantos achievements um usuário desbloqueou em um game.

  ## Exemplos
      iex> count_user_achievements(profile_game_id)
      42
  """
  def count_user_achievements(profile_game_id) do
    ProfileAchievement
    |> where([pa], pa.profile_game_id == ^profile_game_id and pa.achieved == true)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Retorna dados de sincronização de um usuário em uma plataforma.

  ## Exemplos
      iex> get_sync_account_data(profile_id, platform_id)
      %{profile: %Profile{}, platform_account: %ProfilePlatformAccount{}, games: [...]}
  """
  def get_sync_account_data(profile_id, platform_id) do
    profile = get_profile(profile_id)
    platform_account = get_platform_account(profile_id, platform_id)
    games = list_user_games(profile_id, platform_id)

    %{
      profile: profile,
      platform_account: platform_account,
      games: games
    }
  end
end
