defmodule ProjetoPrisma.Profiles.ProfilePlatformAccount do
  use Ecto.Schema
  import Ecto.Changeset

  alias ProjetoPrisma.Profiles.Profile
  alias ProjetoPrisma.Catalog.Platform

  schema "profile_platform_accounts" do
    field :external_user_id, :string
    field :profile_url, :string

    belongs_to :profile, Profile
    belongs_to :platform, Platform
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [:external_user_id, :profile_url, :profile_id, :platform_id])
    |> validate_required([:external_user_id, :profile_id, :platform_id])
    |> unique_constraint([:profile_id, :platform_id])
  end
end
