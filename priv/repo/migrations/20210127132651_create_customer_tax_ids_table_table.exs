defmodule Tailcall.Repo.Migrations.CreateCustomerTaxIdsTableTable do
  use Ecto.Migration

  def change do
    create table(:customer_tax_ids, primary_key: false) do
      add(:id, :uuid, primary_key: true)

      add(:livemode, :boolean, null: false)
      add(:started_at, :utc_datetime, null: false)
      add(:ended_at, :utc_datetime, null: true)

      add(:user_id, :bigint, null: false)
      add(:customer_id, references(:customers, on_delete: :nothing), null: false)

      add(:country, :string, null: true)
      add(:type, :string, null: false)
      add(:value, :string, null: false)

      timestamps()
      add(:object, :string, default: "customer_tax_id")
    end

    create(index(:customer_tax_ids, [:livemode]))
    create(index(:customer_tax_ids, [:started_at]))
    create(index(:customer_tax_ids, [:ended_at]))
    create(index(:customer_tax_ids, [:user_id]))

    create table(:customer_tax_id_verifications, primary_key: false) do
      add(:id, :uuid, primary_key: true)

      add(:started_at, :utc_datetime, null: false)
      add(:ended_at, :utc_datetime, null: true)

      add(:customer_tax_id_id, references(:customer_tax_ids, type: :uuid, on_delete: :nothing),
        null: false
      )

      add(:status, :string, null: false)
      add(:verified_address, :string, null: true)
      add(:verified_name, :string, null: true)

      timestamps()
      add(:object, :string, default: "customer_tax_id_verification")
    end
  end
end
