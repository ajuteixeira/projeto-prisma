defmodule ProjetoPrisma.Repo.Migrations.CreateProfileAchievements do
  use Ecto.Migration

  def change do
    create table(:profile_achievements) do
      add :user_game_id, references(:profile_games, on_delete: :delete_all), null: false
      add :achievement_id, references(:achievements, on_delete: :delete_all), null: false
      add :achieved, :boolean, default: false
      add :unlock_time, :naive_datetime
    end

    create unique_index(:profile_achievements, [:user_game_id, :achievement_id])
  end
end
