defmodule ProjetoPrisma.Repo.Migrations.CreatePlatformGames do
  use Ecto.Migration

  def change do
    create table(:platform_games) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :platform_id, references(:platforms, on_delete: :delete_all), null: false
      add :external_game_id, :string
    end

    create unique_index(:platform_games, [:platform_id, :external_game_id])
  end
end
