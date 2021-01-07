defmodule Tailcall.Repo.Migrations.CreateEventsTable do
  use Ecto.Migration

  def change do
    create table(:events) do
      add(:user_id, :bigint)

      add(:api_version, :string, null: false)
      add(:created_at, :utc_datetime, null: false)
      add(:data, :map, null: false)
      add(:livemode, :boolean, null: false)
      add(:request_id, :string, null: true)
      add(:resource_id, :string, null: true)
      add(:resource_type, :string, null: true)
      add(:type, :string, null: false)

      timestamps()
      add(:object, :string, default: "event")
    end

    create(index(:events, [:user_id]))

    create(index(:events, [:created_at]))
    create(index(:events, [:livemode]))
    create(index(:events, [:type]))
    create(index(:events, [:request_id]))
    create(index(:events, [:resource_id]))
    create(index(:events, [:resource_type, :resource_id]))
  end
end
