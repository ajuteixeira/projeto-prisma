defmodule ProjetoPrisma.Catalog.Achievement do
  use Ecto.Schema
  import Ecto.Changeset

  alias ProjetoPrisma.Catalog.PlatformGame

  schema "achievements" do
    field :external_achievement_id, :string
    field :name, :string
    field :description, :string
    field :icon_image, :string
    field :icon_locked_image, :string

    belongs_to :platform_game, PlatformGame
  end

  def changeset(achievement, attrs) do
    achievement
    |> cast(attrs, [:external_achievement_id, :name, :description, :icon_image, :icon_locked_image, :platform_game_id])
    |> validate_required([:external_achievement_id, :name, :platform_game_id])
    |> unique_constraint([:platform_game_id, :external_achievement_id])
  end
end
