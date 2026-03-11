defmodule ProjetoPrisma.Repo.Migrations.CreatePlatforms do
  use Ecto.Migration

  def change do
    create table(:platforms) do
      add :name, :string
      add :slug, :string
    end

    create unique_index(:platforms, [:name])
  end
end
