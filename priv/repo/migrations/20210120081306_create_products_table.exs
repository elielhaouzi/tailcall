defmodule Tailcall.Repo.Migrations.CreateProductsTable do
  use Ecto.Migration

  def change do
    create table(:products) do
      add(:account_id, :bigint, null: false)

      add(:active, :boolean, null: false)
      add(:caption, :string, null: true)
      add(:created_at, :utc_datetime, null: false)
      add(:description, :string, null: true)
      add(:livemode, :boolean, null: false)
      add(:metadata, :map, null: true)
      add(:name, :string, null: false)
      add(:statement_descriptor, :string, null: true)
      add(:type, :string, null: false)
      add(:unit_label, :string, null: true)
      add(:url, :string, null: true)

      add(:deleted_at, :utc_datetime, null: true)
      timestamps()
      add(:object, :string, default: "product")
    end

    create(index(:products, [:account_id]))

    create(index(:products, [:active]))
    create(index(:products, [:created_at]))
    create(index(:products, [:deleted_at]))
    create(index(:products, [:livemode]))
    create(index(:products, [:type]))
  end
end
