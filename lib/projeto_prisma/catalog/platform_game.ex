defmodule ProjetoPrisma.Catalog.PlatformGame do
  use Ecto.Schema
  import Ecto.Changeset

  alias ProjetoPrisma.Catalog.{Platform, Game}

  schema "platform_games" do
    field :external_game_id, :string

    belongs_to :game, Game
    belongs_to :platform, Platform
  end

  def changeset(platform_game, attrs) do
    platform_game
    |> cast(attrs, [:external_game_id, :game_id, :platform_id])
    |> validate_required([:external_game_id, :game_id, :platform_id])
    |> unique_constraint([:platform_id, :external_game_id])
  end
end
