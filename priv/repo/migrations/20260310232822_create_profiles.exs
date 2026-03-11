defmodule ProjetoPrisma.Repo.Migrations.CreateProfiles do
  use Ecto.Migration

  def change do
    create table(:profiles) do
      add :username, :string
    end
  end
end
