defmodule Tailcall.Repo.Migrations.CreateCustomersTable do
  use Ecto.Migration

  def change do
    create table(:customers) do
      add(:user_id, :bigint, null: false)

      add(:address, :map, null: true)
      add(:balance, :integer, null: false)
      add(:currency, :string, null: false)
      add(:created_at, :utc_datetime, null: false)
      add(:delinquent, :boolean, null: false)
      add(:description, :string, null: true)
      add(:email, :string, null: true)
      add(:invoice_prefix, :string, null: true)
      add(:invoice_settings, :map, null: false)
      add(:livemode, :boolean, null: false)
      add(:metadata, :map, null: true)
      add(:name, :string, null: true)
      add(:next_invoice_sequence, :integer, null: false)
      add(:phone, :string, null: true)
      add(:preferred_locales, {:array, :string}, default: [], null: false)
      add(:shipping, :map, null: true)
      add(:tax_exempt, :string, null: false)

      add(:deleted_at, :utc_datetime, null: true)
      timestamps()
      add(:object, :string, default: "customer")
    end

    create(index(:customers, [:created_at]))
    create(index(:customers, [:delinquent]))
    create(index(:customers, [:email]))
    create(unique_index(:customers, [:invoice_prefix]))
    create(index(:customers, [:phone]))
    create(index(:customers, [:deleted_at]))
    create(index(:customers, [:livemode]))

  end
end
