defmodule ProjetoPrisma.Repo.Migrations.CreateAchievements do
  use Ecto.Migration

  def change do
    create table(:achievements) do
      add :platform_game_id, references(:platform_games, on_delete: :delete_all), null: false
      add :external_achievement_id, :string
      add :name, :string
      add :description, :text
      add :icon_image, :string
      add :icon_locked_image, :string
    end

    create unique_index(:achievements, [:platform_game_id, :external_achievement_id])
  end
end
