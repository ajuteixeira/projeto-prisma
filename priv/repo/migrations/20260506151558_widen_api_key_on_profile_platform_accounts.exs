defmodule ProjetoPrisma.Repo.Migrations.WidenApiKeyOnProfilePlatformAccounts do
  use Ecto.Migration

  def up do
    alter table(:profile_platform_accounts) do
      modify :api_key, :text
    end
  end

  def down do
    alter table(:profile_platform_accounts) do
      modify :api_key, :string
    end
  end
end
