defmodule Accounts.Repo.Migrations.CreateApiKeysTable do
  use Ecto.Migration

  def change do
    create table(:api_keys) do
      add(:user_id, references(:users, on_delete: :delete_all), null: false)

      add(:created_at, :utc_datetime, null: false)
      add(:expired_at, :utc_datetime, null: true)
      add(:livemode, :boolean, null: false)
      add(:secret, :string, null: false)
      add(:type, :string, null: false)

      timestamps()
      add(:object, :binary, default: "api_key")
    end

    create(index(:api_keys, [:created_at]))
    create(index(:api_keys, [:expired_at]))
    create(index(:api_keys, [:livemode]))
    create(unique_index(:api_keys, [:secret]))
  end
end
