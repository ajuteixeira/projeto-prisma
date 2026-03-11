defmodule ProjetoPrisma.Repo.Migrations.CreateProfilePlatformAccounts do
  use Ecto.Migration

  def change do
    create table(:profile_platform_accounts) do
      add :profile_id, references(:profiles, on_delete: :delete_all), null: false
      add :platform_id, references(:platforms, on_delete: :delete_all), null: false
      add :external_user_id, :string
      add :profile_url, :string
    end

    create unique_index(:profile_platform_accounts, [:profile_id, :platform_id])
  end
end
