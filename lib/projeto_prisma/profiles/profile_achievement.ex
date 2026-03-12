defmodule ProjetoPrisma.Profiles.ProfileAchievement do
  use Ecto.Schema
  import Ecto.Changeset

  alias ProjetoPrisma.Profiles.ProfileGame
  alias ProjetoPrisma.Catalog.Achievement

  schema "profile_achievements" do
    field :achieved, :boolean, default: false
    field :unlock_time, :naive_datetime

    belongs_to :profile_game, ProfileGame
    belongs_to :achievement, Achievement
  end

  def changeset(profile_achievement, attrs) do
    profile_achievement
    |> cast(attrs, [:achieved, :unlock_time, :profile_game_id, :achievement_id])
    |> validate_required([:profile_game_id, :achievement_id, :achieved])
    |> unique_constraint([:profile_game_id, :achievement_id])
  end
end
