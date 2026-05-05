defmodule ProjetoPrisma.Repo.Migrations.AddPinnedPositionToProfileAchievements do
  use Ecto.Migration

  def change do
    alter table(:profile_achievements) do
      add(:pinned_position, :integer)
    end

    create(
      constraint(:profile_achievements, :profile_achievements_pinned_position_between_1_and_4,
        check: "pinned_position IS NULL OR pinned_position BETWEEN 1 AND 4"
      )
    )

    create(index(:profile_achievements, [:pinned_position], where: "pinned_position IS NOT NULL"))
  end
end
