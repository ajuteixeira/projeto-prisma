defmodule ProjetoPrisma.Sync.PlatformBehaviour do
  @moduledoc """
  Behaviour que define o contrato para integrações com plataformas de jogos (Steam, PlayStation, Xbox, etc).

  Cada adapter implementa essas funções para normalizar dados da API externa pro schema interno.
  """

  @type account :: %{
    external_user_id: String.t(),
    api_key: String.t(),
    platform_id: integer()
  }

  @type game :: %{
    external_game_id: String.t(),
    name: String.t(),
    cover_image: String.t() | nil,
    icon_image: String.t() | nil,
    logo_image: String.t() | nil,
    playtime_minutes: integer() | nil
  }

  @type achievement :: %{
    external_achievement_id: String.t(),
    name: String.t(),
    description: String.t() | nil,
    icon_image: String.t() | nil,
    icon_locked_image: String.t() | nil,
    achieved: boolean(),
    unlock_time: DateTime.t() | nil
  }

  @doc """
  Busca os jogos que o usuário possui na plataforma.

  Retorna uma lista de jogos normalizados.
  """
  @callback fetch_games(account :: account()) :: {:ok, [game()]} | {:error, term()}

  @doc """
  Busca os achievements de um jogo específico que o usuário desbloqueou.

  Retorna uma lista de achievements normalizados.
  """
  @callback fetch_achievements(account :: account(), game_external_id :: String.t()) ::
              {:ok, [achievement()]} | {:error, term()}
end
