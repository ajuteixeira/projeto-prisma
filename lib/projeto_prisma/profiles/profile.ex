defmodule ProjetoPrisma.Profiles.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "profiles" do
    field :username, :string
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:username])
    |> validate_required([:username])
  end
end
