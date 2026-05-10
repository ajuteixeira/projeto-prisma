defmodule ProjetoPrisma.Repo.Migrations.WidenAchievementImageColumns do
  use Ecto.Migration

  def up do
    alter table(:achievements) do
      modify :icon_image, :text
      modify :icon_locked_image, :text
    end

    alter table(:games) do
      modify :cover_image, :text
      modify :icon_image, :text
      modify :logo_image, :text
    end
  end

  def down do
    alter table(:achievements) do
      modify :icon_image, :string
      modify :icon_locked_image, :string
    end

    alter table(:games) do
      modify :cover_image, :string
      modify :icon_image, :string
      modify :logo_image, :string
    end
  end
end
