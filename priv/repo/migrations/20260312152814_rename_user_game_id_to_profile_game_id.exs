defmodule ProjetoPrisma.Repo.Migrations.RenameUserGameIdToProfileGameId do
  use Ecto.Migration

  def change do
    rename table(:profile_achievements), :user_game_id, to: :profile_game_id
  end
end
