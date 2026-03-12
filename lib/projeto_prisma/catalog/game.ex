defmodule ProjetoPrisma.Catalog.Game do
  use Ecto.Schema
  import Ecto.Changeset

  schema "games" do
    field :igdb_id, :integer
    field :name, :string
    field :cover_image, :string
    field :icon_image, :string
    field :logo_image, :string
  end

  def changeset(game, attrs) do
    game
    |> cast(attrs, [:igdb_id, :name, :cover_image, :icon_image, :logo_image])
    |> validate_required([:name])
    |> unique_constraint(:igdb_id)
  end
end
