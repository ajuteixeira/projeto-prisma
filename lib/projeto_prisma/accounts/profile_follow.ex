defmodule ProjetoPrisma.Accounts.ProfileFollow do
  use Ecto.Schema
  import Ecto.Changeset

  schema "profile_follows" do
    belongs_to :follower_profile, ProjetoPrisma.Accounts.Profile,
      foreign_key: :follower_profile_id

    belongs_to :followed_profile, ProjetoPrisma.Accounts.Profile,
      foreign_key: :followed_profile_id

    timestamps()
  end

  def changeset(profile_follow, attrs) do
    profile_follow
    |> cast(attrs, [:follower_profile_id, :followed_profile_id])
    |> validate_required([:follower_profile_id, :followed_profile_id])
    |> unique_constraint([:follower_profile_id, :followed_profile_id],
      name: :profile_follows_unique_pair
    )
  end
end
