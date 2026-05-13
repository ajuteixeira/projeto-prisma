defmodule ProjetoPrisma.Accounts do
  @moduledoc """
  Context para gerenciar profiles de usuários e suas contas em plataformas.

  Encapsula lógica de criar/buscar profiles, contas de plataforma,
  e games/achievements sincronizados do usuário.
  """

  import Ecto.Query
  alias ProjetoPrisma.Repo

  alias ProjetoPrisma.Accounts.{
    User,
    Profile,
    ProfileFollow,
    ProfilePlatformAccount,
    ProfileGame,
    ProfileAchievement,
    Scope
  }

  alias ProjetoPrisma.Catalog.{Achievement, Platform, PlatformGame}

  @doc """
  Registra um novo usuário com senha hasheada.

  ## Parâmetros
    - `attrs` - %{email: "user@example.com", password: "secret123", username: "john_doe", full_name: "John Doe"}

  ## Exemplos
      iex> register_user(%{email: "user@example.com", password: "secret123", username: "john_doe"})
      {:ok, %User{}}
  """
  def register_user_legacy(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Cria um profile vinculado a um usuário.

  ## Parâmetros
    - `user` - %User{} com id e username

  ## Exemplos
      iex> create_profile_for_user(user)
      {:ok, %Profile{}}
  """
  def create_profile_for_user(user) do
    %Profile{}
    |> Profile.changeset(%{username: user.username, user_id: user.id})
    |> Repo.insert()
  end

  @doc """
  Autentica um usuário por email e senha.

  ## Parâmetros
    - `email` - Email do usuário
    - `password` - Senha em texto plano

  ## Exemplos
      iex> authenticate_user("user@example.com", "secret123")
      {:ok, %User{}}

      iex> authenticate_user("user@example.com", "wrong_password")
      {:error, :invalid_password}
  """
  def authenticate_user(email, password) do
    user = Repo.get_by(User, email: String.downcase(String.trim(email)))

    cond do
      user && User.valid_password?(user, password) ->
        {:ok, user}

      user ->
        {:error, :invalid_password}

      true ->
        Bcrypt.no_user_verify()
        {:error, :not_found}
    end
  end

  @doc """
  Redefine a senha de um usuário pelo email.
  """
  def reset_user_password_by_email(email, new_password) do
    case get_user_by_email(email) do
      nil ->
        {:error, :not_found}

      user ->
        user
        |> User.password_reset_changeset(%{password: new_password})
        |> Repo.update()
    end
  end

  @doc """
  Busca um usuário pelo ID e precarrega o profile.

  ## Exemplos
      iex> get_user_with_profile(1)
      %User{profile: %Profile{}}
  """
  def get_user_with_profile(user_id) do
    User
    |> Repo.get(user_id)
    |> Repo.preload(:profile)
  end

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
  Busca um profile pelo username.

  ## Exemplos
      iex> get_profile_by_username("fulano")
      %Profile{} | nil
  """
  def get_profile_by_username(username) when is_binary(username) do
    normalized = String.downcase(String.trim(username))

    Profile
    |> where([p], fragment("lower(?)", p.username) == ^normalized)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Busca um profile com o user precarregado usando o Scope.

  ## Exemplos
      iex> get_profile_with_user(%Scope{user: %User{id: 1}})
      %Profile{user: %User{}} | nil
  """
  def get_profile_with_user(%ProjetoPrisma.Accounts.Scope{user: %User{id: user_id}}) do
    Profile
    |> where([p], p.user_id == ^user_id)
    |> preload([:user, :avatar])
    |> Repo.one()
  end

  def get_profile_with_user(_scope), do: nil

  @doc """
  Lista os seguidores de um profile.
  """
  def list_followers(profile_id) when is_integer(profile_id) do
    ProfileFollow
    |> where([pf], pf.followed_profile_id == ^profile_id)
    |> join(:inner, [pf], p in Profile, on: p.id == pf.follower_profile_id)
    |> select([_pf, p], p)
    |> order_by([pf], desc: pf.inserted_at)
    |> Repo.all()
    |> Repo.preload([:user, :avatar])
  end

  def list_followers(_profile_id), do: []

  @doc """
  Lista quem o profile esta seguindo.
  """
  def list_following(profile_id) when is_integer(profile_id) do
    ProfileFollow
    |> where([pf], pf.follower_profile_id == ^profile_id)
    |> join(:inner, [pf], p in Profile, on: p.id == pf.followed_profile_id)
    |> select([_pf, p], p)
    |> order_by([pf], desc: pf.inserted_at)
    |> Repo.all()
    |> Repo.preload([:user, :avatar])
  end

  def list_following(_profile_id), do: []

  @doc """
  Lista apenas os IDs seguidos por um profile.
  """
  def list_following_ids(profile_id) when is_integer(profile_id) do
    ProfileFollow
    |> where([pf], pf.follower_profile_id == ^profile_id)
    |> select([pf], pf.followed_profile_id)
    |> Repo.all()
  end

  def list_following_ids(_profile_id), do: []

  @doc """
  Conta seguidores de um profile.
  """
  def count_profile_followers(profile_id) when is_integer(profile_id) do
    ProfileFollow
    |> where([pf], pf.followed_profile_id == ^profile_id)
    |> Repo.aggregate(:count, :id)
  end

  def count_profile_followers(_profile_id), do: 0

  @doc """
  Conta quem o profile esta seguindo.
  """
  def count_profile_following(profile_id) when is_integer(profile_id) do
    ProfileFollow
    |> where([pf], pf.follower_profile_id == ^profile_id)
    |> Repo.aggregate(:count, :id)
  end

  def count_profile_following(_profile_id), do: 0

  @doc """
  Busca perfis por username (apenas username), excluindo o profile atual.
  """
  def search_profiles_by_username(profile_id, query, opts \\ [])

  def search_profiles_by_username(profile_id, query, opts) when is_integer(profile_id) do
    search = normalize_search(query)

    if search == "" do
      []
    else
      pattern = "%#{search}%"
      limit = option_value(opts, :limit, 24)

      Profile
      |> where([p], p.id != ^profile_id)
      |> where([p], ilike(p.username, ^pattern))
      |> preload([:user, :avatar])
      |> order_by([p], asc: p.username)
      |> limit(^limit)
      |> Repo.all()
    end
  end

  def search_profiles_by_username(_profile_id, _query, _opts), do: []

  @doc """
  Verifica se um profile segue outro.
  """
  def following?(follower_profile_id, followed_profile_id)
      when is_integer(follower_profile_id) and is_integer(followed_profile_id) do
    ProfileFollow
    |> where(
      [pf],
      pf.follower_profile_id == ^follower_profile_id and
        pf.followed_profile_id == ^followed_profile_id
    )
    |> Repo.exists?()
  end

  def following?(_follower_profile_id, _followed_profile_id), do: false

  @doc """
  Segue um profile.
  """
  def follow_profile(follower_profile_id, followed_profile_id)
      when is_integer(follower_profile_id) and is_integer(followed_profile_id) do
    cond do
      follower_profile_id == followed_profile_id ->
        {:error, :cannot_follow_self}

      true ->
        %ProfileFollow{}
        |> ProfileFollow.changeset(%{
          follower_profile_id: follower_profile_id,
          followed_profile_id: followed_profile_id
        })
        |> Repo.insert(
          on_conflict: :nothing,
          conflict_target: [:follower_profile_id, :followed_profile_id]
        )
        |> case do
          {:ok, _follow} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  def follow_profile(_follower_profile_id, _followed_profile_id),
    do: {:error, :invalid_profile}

  @doc """
  Deixa de seguir um profile.
  """
  def unfollow_profile(follower_profile_id, followed_profile_id)
      when is_integer(follower_profile_id) and is_integer(followed_profile_id) do
    ProfileFollow
    |> where(
      [pf],
      pf.follower_profile_id == ^follower_profile_id and
        pf.followed_profile_id == ^followed_profile_id
    )
    |> Repo.delete_all()

    :ok
  end

  def unfollow_profile(_follower_profile_id, _followed_profile_id),
    do: {:error, :invalid_profile}

  @doc """
  Alterna follow/unfollow e retorna o novo estado.
  """
  def toggle_follow(follower_profile_id, followed_profile_id)
      when is_integer(follower_profile_id) and is_integer(followed_profile_id) do
    if following?(follower_profile_id, followed_profile_id) do
      with :ok <- unfollow_profile(follower_profile_id, followed_profile_id) do
        {:ok, :unfollowed}
      end
    else
      with :ok <- follow_profile(follower_profile_id, followed_profile_id) do
        {:ok, :followed}
      end
    end
  end

  def toggle_follow(_follower_profile_id, _followed_profile_id),
    do: {:error, :invalid_profile}

  @doc """
  Retorna um changeset para alterar o profile.

  ## Exemplos
      iex> change_profile(%Scope{user: %User{}})
      %Ecto.Changeset{}

      iex> change_profile(%Scope{user: %User{}}, %{username: "novo"})
      %Ecto.Changeset{}
  """
  def change_profile(scope, attrs \\ %{})

  def change_profile(%ProjetoPrisma.Accounts.Scope{user: %User{id: user_id}}, attrs) do
    profile = Repo.get_by(Profile, user_id: user_id) || %Profile{user_id: user_id}
    Profile.changeset(profile, attrs)
  end

  def change_profile(_scope, _attrs), do: Profile.changeset(%Profile{}, %{})

  @doc """
  Atualiza um profile com os novos atributos.

  ## Exemplos
      iex> update_profile(%Scope{user: %User{}}, %{username: "novo"})
      {:ok, %Profile{}}

      iex> update_profile(%Scope{user: %User{}}, %{username: ""})
      {:error, %Ecto.Changeset{}}
  """
  def update_profile(%ProjetoPrisma.Accounts.Scope{user: %User{id: user_id}}, attrs) do
    case Repo.get_by(Profile, user_id: user_id) do
      nil ->
        {:error, :profile_not_found}

      profile ->
        profile
        |> Profile.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, updated_profile} ->
            {:ok, Repo.preload(updated_profile, [:user, :avatar])}

          error ->
            error
        end
    end
  end

  def update_profile(_scope, _attrs), do: {:error, :profile_not_found}

  @doc """
  Atualiza o full_name do usuario.
  """
  def update_user_full_name(%ProjetoPrisma.Accounts.Scope{user: %User{id: user_id}}, full_name) do
    case Repo.get(User, user_id) do
      nil ->
        {:error, :user_not_found}

      user ->
        user
        |> User.full_name_changeset(%{full_name: full_name})
        |> Repo.update()
    end
  end

  def update_user_full_name(_scope, _full_name), do: {:error, :user_not_found}

  @doc """
  Atualiza o username do usuario (tabela users).
  Tambem atualiza o username do profile em cascata.
  """
  def update_user_username(%ProjetoPrisma.Accounts.Scope{user: %User{id: user_id}}, username) do
    Repo.transact(fn ->
      with %User{} = user <- Repo.get(User, user_id),
           {:ok, updated_user} <-
             user |> User.username_changeset(%{username: username}) |> Repo.update(),
           %Profile{} = profile <- Repo.get_by(Profile, user_id: user_id),
           {:ok, _updated_profile} <-
             profile |> Profile.changeset(%{username: username}) |> Repo.update() do
        {:ok, updated_user}
      else
        nil -> {:error, :not_found}
        {:error, changeset} -> {:error, changeset}
      end
    end)
  end

  def update_user_username(_scope, _username), do: {:error, :user_not_found}

  @doc """
  Cria ou atualiza o avatar do perfil.
  """
  def upsert_profile_avatar(
        %ProjetoPrisma.Accounts.Scope{user: %User{id: user_id}},
        data,
        content_type
      ) do
    alias ProjetoPrisma.Accounts.ProfileAvatar

    case Repo.get_by(Profile, user_id: user_id) do
      nil ->
        {:error, :profile_not_found}

      profile ->
        case Repo.get_by(ProfileAvatar, profile_id: profile.id) do
          nil ->
            %ProfileAvatar{}
            |> ProfileAvatar.changeset(%{
              profile_id: profile.id,
              data: data,
              content_type: content_type
            })
            |> Repo.insert()

          avatar ->
            avatar
            |> ProfileAvatar.changeset(%{data: data, content_type: content_type})
            |> Repo.update()
        end
    end
  end

  def upsert_profile_avatar(_scope, _data, _content_type), do: {:error, :profile_not_found}

  @doc """
  Verifica se um username já está em uso por outro usuario.

  ## Exemplos
      iex> username_taken?(%Scope{user: %User{id: 1}}, "fulano")
      true | false
  """
  def username_taken?(%ProjetoPrisma.Accounts.Scope{user: %User{id: user_id}}, username)
      when is_binary(username) do
    normalized = String.downcase(String.trim(username))

    # Check users table (primary source of truth)
    User
    |> where([u], fragment("lower(?)", u.username) == ^normalized)
    |> where([u], u.id != ^user_id)
    |> Repo.exists?()
  end

  def username_taken?(_scope, _username), do: false

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
          Map.merge(stringify_keys(attrs), %{
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
  Lista os slugs das plataformas conectadas para um profile.

  ## Exemplos
      iex> list_connected_platform_slugs(1)
      ["steam", "xbox"]
  """
  def list_connected_platform_slugs(profile_id) do
    ProfilePlatformAccount
    |> join(:inner, [ppa], p in Platform, on: p.id == ppa.platform_id)
    |> where([ppa, _p], ppa.profile_id == ^profile_id)
    |> select([_ppa, p], p.slug)
    |> distinct(true)
    |> Repo.all()
  end

  @doc """
  Lista as contas de plataforma conectadas de um profile com a plataforma precarregada.
  """
  def list_connected_platform_accounts(profile_id) do
    ProfilePlatformAccount
    |> where([ppa], ppa.profile_id == ^profile_id)
    |> preload(:platform)
    |> Repo.all()
  end

  @doc """
  Conecta uma conta de plataforma por slug para um profile.

  Retorna `{:ok, %ProfilePlatformAccount{}}` quando já existe ou quando cria.
  """
  def connect_platform_account(profile_id, platform_slug, attrs) do
    case Repo.get_by(Platform, slug: platform_slug) do
      nil ->
        {:error, :platform_not_found}

      platform ->
        get_or_create_platform_account(profile_id, platform.id, attrs)
    end
  end

  @doc """
  Desconecta uma conta de plataforma por slug de um profile.

  Retorna `{:ok, :not_connected}` caso não exista vínculo.
  """
  def disconnect_platform_account(profile_id, platform_slug) do
    with %Platform{} = platform <- Repo.get_by(Platform, slug: platform_slug) do
      case Repo.get_by(ProfilePlatformAccount, profile_id: profile_id, platform_id: platform.id) do
        nil -> {:ok, :not_connected}
        account -> Repo.delete(account)
      end
    else
      nil -> {:error, :platform_not_found}
    end
  end

  @doc """
  Atualiza credenciais de uma conta de plataforma por id.

  Usado, por exemplo, quando o provedor (Microsoft) rotaciona o refresh token
  durante uma sincronização.
  """
  def update_platform_credential(account_id, attrs) do
    case Repo.get(ProfilePlatformAccount, account_id) do
      nil ->
        {:error, :not_found}

      account ->
        account
        |> ProfilePlatformAccount.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Marca o início de uma sincronização de uma conta de plataforma.
  """
  def mark_platform_sync_started(%ProfilePlatformAccount{} = account, step) do
    account
    |> ProfilePlatformAccount.changeset(%{
      sync_status: "running",
      sync_step: step,
      sync_last_error: nil,
      sync_started_at: DateTime.utc_now() |> DateTime.to_naive(),
      sync_finished_at: nil,
      sync_attempts: (account.sync_attempts || 0) + 1
    })
    |> Repo.update()
  end

  @doc """
  Marca a sincronização como concluída.
  """
  def mark_platform_sync_finished(%ProfilePlatformAccount{} = account, step, attrs \\ %{}) do
    account
    |> ProfilePlatformAccount.changeset(
      Map.merge(attrs, %{
        sync_status: "completed",
        sync_step: step,
        sync_last_error: nil,
        sync_finished_at: DateTime.utc_now() |> DateTime.to_naive()
      })
    )
    |> Repo.update()
  end

  @doc """
  Marca a sincronização como falha para permitir retomada posterior.
  """
  def mark_platform_sync_failed(%ProfilePlatformAccount{} = account, step, reason) do
    account
    |> ProfilePlatformAccount.changeset(%{
      sync_status: "failed",
      sync_step: step,
      sync_last_error: format_sync_error(reason),
      sync_finished_at: DateTime.utc_now() |> DateTime.to_naive()
    })
    |> Repo.update()
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
          Map.merge(stringify_keys(attrs), %{
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
          Map.merge(stringify_keys(attrs), %{
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
  Lista as conquistas desbloqueadas do usuario logado.

  Aceita `:search` para filtrar pelo nome da conquista ou do jogo.
  """
  def list_achieved_achievements(scope, opts \\ [])

  def list_achieved_achievements(%Scope{user: %User{id: user_id}}, opts) do
    search = opts |> option_value(:search, "") |> normalize_search()

    user_id
    |> profile_achievement_display_query()
    |> where([pa, _pg, _profile, _achievement, _platform_game, _game], pa.achieved == true)
    |> maybe_filter_achievement_search(search)
    |> order_achievement_display_query()
    |> Repo.all()
  end

  def list_achieved_achievements(_scope, _opts), do: []

  @doc """
  Lista as conquistas fixadas do usuario logado ordenadas pela posicao.
  """
  def list_pinned_achievements(%Scope{user: %User{id: user_id}}) do
    user_id
    |> profile_achievement_display_query()
    |> where(
      [pa, _pg, _profile, _achievement, _platform_game, _game],
      pa.achieved == true and not is_nil(pa.pinned_position)
    )
    |> order_by([pa, _pg, _profile, _achievement, _platform_game, _game], asc: pa.pinned_position)
    |> Repo.all()
  end

  def list_pinned_achievements(_scope), do: []

  @doc """
  Atualiza as conquistas fixadas do usuario logado.

  Recebe uma lista ordenada com ate 4 IDs de `profile_achievements`.
  """
  def update_pinned_achievements(scope, profile_achievement_ids)

  def update_pinned_achievements(
        %Scope{user: %User{id: user_id}} = scope,
        profile_achievement_ids
      ) do
    with {:ok, ids} <- normalize_profile_achievement_ids(profile_achievement_ids),
         :ok <- validate_pinned_achievement_count(ids),
         %Profile{} = profile <- Repo.get_by(Profile, user_id: user_id),
         :ok <- validate_pinned_achievement_selection(profile.id, ids) do
      Repo.transaction(fn ->
        profile.id
        |> pinned_profile_achievements_query()
        |> Repo.update_all(set: [pinned_position: nil])

        ids
        |> Enum.with_index(1)
        |> Enum.each(fn {id, position} ->
          ProfileAchievement
          |> where([pa], pa.id == ^id)
          |> Repo.update_all(set: [pinned_position: position])
        end)

        list_pinned_achievements(scope)
      end)
    else
      :too_many_pins -> {:error, :too_many_pins}
      :invalid_achievement_selection -> {:error, :invalid_achievement_selection}
      nil -> {:error, :profile_not_found}
    end
  end

  def update_pinned_achievements(_scope, _profile_achievement_ids),
    do: {:error, :profile_not_found}

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

  @doc """
  Retorna o ranking de jogadores para um perfil: o próprio usuário e as pessoas que ele segue,
  ordenados por total de conquistas desbloqueadas (decrescente).

  Cada entrada retorna:
    - profile: %Profile{} com user e avatar precarregados
    - achievement_count: total de conquistas desbloqueadas
    - platform_slugs: lista de slugs das plataformas conectadas (ex: ["psn", "steam"])
    - is_current_user: true se for o próprio usuário logado
  """
  def ranking_for_profile(profile_id) when is_integer(profile_id) do
    followed_ids = list_following_ids(profile_id)
    all_profile_ids = [profile_id | followed_ids]

    raw_counts =
      (from pa in ProfileAchievement,
        join: pg in ProfileGame, on: pg.id == pa.profile_game_id,
        join: ppg in PlatformGame, on: ppg.id == pg.platform_game_id,
        join: plat in Platform, on: plat.id == ppg.platform_id,
        where: pg.profile_id in ^all_profile_ids and pa.achieved == true,
        group_by: [pg.profile_id, plat.slug],
        select: {pg.profile_id, plat.slug, count(pa.id)})
      |> Repo.all()

    counts_by_profile =
      Enum.reduce(raw_counts, %{}, fn {pid, _slug, cnt}, acc ->
        Map.update(acc, pid, cnt, &(&1 + cnt))
      end)

    platform_counts_by_profile =
      Enum.reduce(raw_counts, %{}, fn {pid, slug, cnt}, acc ->
        Map.update(acc, pid, %{slug => cnt}, &Map.put(&1, slug, cnt))
      end)

    platforms_by_profile =
      (from ppa in ProfilePlatformAccount,
        join: plat in Platform,
        on: plat.id == ppa.platform_id,
        where: ppa.profile_id in ^all_profile_ids,
        select: {ppa.profile_id, plat.slug})
      |> Repo.all()
      |> Enum.group_by(fn {pid, _slug} -> pid end, fn {_pid, slug} -> slug end)

    profiles =
      Profile
      |> where([p], p.id in ^all_profile_ids)
      |> preload([:user, :avatar])
      |> Repo.all()

    profiles
    |> Enum.map(fn profile ->
      %{
        profile: profile,
        achievement_count: Map.get(counts_by_profile, profile.id, 0),
        platform_counts: Map.get(platform_counts_by_profile, profile.id, %{}),
        platform_slugs: Map.get(platforms_by_profile, profile.id, []),
        is_current_user: profile.id == profile_id
      }
    end)
    |> Enum.sort_by(& &1.achievement_count, :desc)
  end

  def ranking_for_profile(_profile_id), do: []

  defp profile_achievement_display_query(user_id) do
    ProfileAchievement
    |> join(:inner, [pa], pg in assoc(pa, :profile_game))
    |> join(:inner, [_pa, pg], profile in Profile, on: profile.id == pg.profile_id)
    |> join(:inner, [pa, _pg, _profile], achievement in assoc(pa, :achievement))
    |> join(:inner, [_pa, pg, _profile, _achievement], platform_game in assoc(pg, :platform_game))
    |> join(
      :inner,
      [_pa, _pg, _profile, _achievement, platform_game],
      game in assoc(platform_game, :game)
    )
    |> where(
      [_pa, _pg, profile, _achievement, _platform_game, _game],
      profile.user_id == ^user_id
    )
    |> select([pa, pg, _profile, achievement, _platform_game, game], %{
      id: pa.id,
      profile_achievement_id: pa.id,
      profile_game_id: pg.id,
      achievement_id: achievement.id,
      name: achievement.name,
      description: achievement.description,
      icon: achievement.icon_image,
      icon_image: achievement.icon_image,
      game_name: game.name,
      achieved: pa.achieved,
      unlock_time: pa.unlock_time,
      pinned_position: pa.pinned_position
    })
  end

  defp maybe_filter_achievement_search(query, ""), do: query

  defp maybe_filter_achievement_search(query, search) do
    pattern = "%#{search}%"

    where(
      query,
      [_pa, _pg, _profile, achievement, _platform_game, game],
      ilike(achievement.name, ^pattern) or ilike(game.name, ^pattern)
    )
  end

  defp order_achievement_display_query(query) do
    order_by(
      query,
      [pa, _pg, _profile, _achievement, _platform_game, _game],
      asc_nulls_last: pa.pinned_position,
      desc_nulls_last: pa.unlock_time,
      asc: pa.id
    )
  end

  defp pinned_profile_achievements_query(profile_id) do
    profile_game_ids_query =
      ProfileGame
      |> where([pg], pg.profile_id == ^profile_id)
      |> select([pg], pg.id)

    ProfileAchievement
    |> where(
      [pa],
      pa.profile_game_id in subquery(profile_game_ids_query) and not is_nil(pa.pinned_position)
    )
  end

  defp validate_pinned_achievement_selection(_profile_id, []), do: :ok

  defp validate_pinned_achievement_selection(profile_id, ids) do
    valid_ids =
      ProfileAchievement
      |> join(:inner, [pa], pg in assoc(pa, :profile_game))
      |> where(
        [pa, pg],
        pg.profile_id == ^profile_id and pa.achieved == true and pa.id in ^ids
      )
      |> select([pa, _pg], pa.id)
      |> Repo.all()

    if MapSet.new(valid_ids) == MapSet.new(ids) do
      :ok
    else
      :invalid_achievement_selection
    end
  end

  defp validate_pinned_achievement_count(ids) when length(ids) <= 4, do: :ok
  defp validate_pinned_achievement_count(_ids), do: :too_many_pins

  defp normalize_profile_achievement_ids(ids) when is_list(ids) do
    normalized =
      Enum.reduce_while(ids, [], fn raw_id, acc ->
        case normalize_profile_achievement_id(raw_id) do
          {:ok, id} -> {:cont, [id | acc]}
          :error -> {:halt, :error}
        end
      end)

    case normalized do
      :error ->
        :invalid_achievement_selection

      ids ->
        ids = Enum.reverse(ids)

        if Enum.uniq(ids) == ids do
          {:ok, ids}
        else
          :invalid_achievement_selection
        end
    end
  end

  defp normalize_profile_achievement_ids(_ids), do: :invalid_achievement_selection

  defp normalize_profile_achievement_id(id) when is_integer(id) and id > 0, do: {:ok, id}

  defp normalize_profile_achievement_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> :error
    end
  end

  defp normalize_profile_achievement_id(_id), do: :error

  defp option_value(opts, key, default) when is_list(opts) do
    Keyword.get(opts, key, default)
  end

  defp option_value(%{} = opts, key, default) do
    Map.get(opts, key) || Map.get(opts, Atom.to_string(key), default)
  end

  defp option_value(_opts, _key, default), do: default

  defp normalize_search(nil), do: ""

  defp normalize_search(search) when is_binary(search) do
    String.trim(search)
  end

  defp normalize_search(search) do
    search
    |> to_string()
    |> String.trim()
  end

  defp format_sync_error(reason) when is_binary(reason), do: reason
  defp format_sync_error(reason), do: inspect(reason)

  defp stringify_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end

  alias ProjetoPrisma.Accounts.{UserToken, UserNotifier}
  alias ProjetoPrisma.Services.EmailResend

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(String.trim(email)))
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password) and not User.deleted?(user), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `ProjetoPrisma.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `ProjetoPrisma.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Delivers the reset password instructions to the given user.
  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    EmailResend.send_password_reset_email(user.email, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.
  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_reset_password_token_query(token),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.
  """
  def reset_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  @doc """
  Soft-deletes a user by setting `deleted_at` and expiring all of their tokens.
  """
  def soft_delete_user(%User{} = user) do
    user
    |> User.soft_delete_changeset()
    |> update_user_and_delete_all_tokens()
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Resolve o `Scope` a partir da sessão Phoenix.

  Retorna `nil` quando o token não existe ou é inválido.
  """
  def resolve_scope_from_session(%{"user_token" => token}) when is_binary(token) do
    case get_user_by_session_token(token) do
      {user, _inserted_at} -> Scope.for_user(user)
      _ -> nil
    end
  end

  def resolve_scope_from_session(_), do: nil

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{deleted_at: %DateTime{}}, _token} ->
        {:error, :not_found}

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
