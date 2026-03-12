defmodule ProjetoPrisma.Profiles.ProfileGame do
  use Ecto.Schema
  import Ecto.Changeset

  alias ProjetoPrisma.Profiles.Profile
  alias ProjetoPrisma.Catalog.PlatformGame

  schema "profile_games" do
    field :playtime_minutes, :integer
    field :last_played, :naive_datetime

    belongs_to :profile, Profile
    belongs_to :platform_game, PlatformGame
  end

  def changeset(profile_game, attrs) do
    profile_game
    |> cast(attrs, [:playtime_minutes, :last_played, :profile_id, :platform_game_id])
    |> validate_required([:profile_id, :platform_game_id, :last_played])
    |> unique_constraint([:profile_id, :platform_game_id])
  end
end
