defmodule Tailcall.Repo.Migrations.CreateInvoicesTable do
  use Ecto.Migration

  def change do
    create table(:invoices) do
      add(:account_id, :bigint, null: false)
      add(:customer_id, :bigint, null: false)

      add(:subscription_id, references(:subscriptions, type: :bigint, on_delete: :nothing),
        null: true
      )

      add(:account_name, :string, null: true)
      add(:amount_due, :integer, null: false)
      add(:amount_paid, :integer, null: false)
      add(:amount_remaining, :integer, null: false)
      add(:billing_reason, :string, null: false)
      add(:created_at, :utc_datetime, null: false)
      add(:customer_email, :string, null: true)
      add(:customer_name, :string, null: true)
      add(:currency, :string, null: false)
      add(:livemode, :boolean, null: false)
      add(:period_end, :utc_datetime, null: false)
      add(:period_start, :utc_datetime, null: false)
      add(:status, :string, null: false)
      add(:total, :integer, null: false)

      add(:deleted_at, :utc_datetime, null: true)
      timestamps()
      add(:object, :string, default: "invoice")
    end

    create(index(:invoices, [:account_id]))
    create(index(:invoices, [:customer_id]))

    create(index(:invoices, [:created_at]))
    create(index(:invoices, [:livemode]))
    create(index(:invoices, [:period_end]))
    create(index(:invoices, [:period_start]))
    create(index(:invoices, [:deleted_at]))
  end
end
