defmodule Accounts.Repo.Migrations.CreateApiKeyUsagesTable do
  use Ecto.Migration

  def change do
    create table(:api_key_usages) do
      add(:api_key_id, references(:api_keys, on_delete: :delete_all), null: false)

      add(:ip_address, :string, null: true)
      add(:request_id, :string, null: true)
      add(:used_at, :utc_datetime_usec, null: false)

      timestamps()
      add(:object, :binary, default: "api_key_usage")
    end

    create(index(:api_key_usages, [:request_id]))
    create(index(:api_key_usages, [:used_at]))
    create(index(:api_key_usages, [:used_at, :id]))
  end
end
