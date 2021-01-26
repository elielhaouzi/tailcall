defmodule Accounts.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:created_at, :utc_datetime, null: false)
      add(:email, :string, null: false)
      add(:name, :string, null: true)
      add(:performer_id, references(:annacl_performers, on_delete: :nothing), null: false)

      add(:deleted_at, :utc_datetime, null: true)
      timestamps()
      add(:object, :string, default: "user")
    end

    create(unique_index(:users, [:email]))
    create(index(:users, [:created_at]))
    create(index(:users, [:deleted_at]))
  end
end
