defmodule ProjetoPrisma.Repo.Migrations.CreateProfileFollows do
  use Ecto.Migration

  def change do
    create table(:profile_follows) do
      add :follower_profile_id, references(:profiles, on_delete: :delete_all), null: false
      add :followed_profile_id, references(:profiles, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:profile_follows, [:follower_profile_id])
    create index(:profile_follows, [:followed_profile_id])

    create unique_index(:profile_follows, [:follower_profile_id, :followed_profile_id],
             name: :profile_follows_unique_pair
           )
  end
end
