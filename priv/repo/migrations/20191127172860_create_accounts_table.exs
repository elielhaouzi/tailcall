defmodule Tailcall.Repo.Migrations.CreateAccountsTable do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add(:api_version, :string, null: false)
      add(:created_at, :utc_datetime, null: false)
      add(:invoice_settings, :map, null: false)
      add(:name, :string, null: true)

      add(:deleted_at, :utc_datetime, null: true)
      timestamps()
      add(:object, :string, default: "account")
    end

    create(index(:accounts, [:created_at]))
    create(index(:accounts, [:deleted_at]))
  end
end
