defmodule ProjetoPrisma.Repo.Migrations.CreateProfileGames do
  use Ecto.Migration

  def change do
    create table(:profile_games) do
      add :profile_id, references(:profiles, on_delete: :delete_all), null: false
      add :platform_game_id, references(:platform_games, on_delete: :delete_all), null: false
      add :playtime_minutes, :integer
      add :last_played, :naive_datetime
    end

    create unique_index(:profile_games, [:profile_id, :platform_game_id])
  end
end
