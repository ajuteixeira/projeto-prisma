defmodule ProjetoPrisma.Catalog.Platform do
  use Ecto.Schema
  import Ecto.Changeset

  schema "platforms" do
    field :name, :string
    field :slug, :string
  end

  def changeset(platform, attrs) do
    platform
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
