defmodule ProjetoPrisma.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :igdb_id, :integer
      add :name, :string
      add :cover_image, :string
      add :icon_image, :string
      add :logo_image, :string
    end

    create unique_index(:games, [:igdb_id])
  end
end
