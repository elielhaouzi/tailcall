defmodule Tailcall.Repo.Migrations.CreateAccountUserTable do
  use Ecto.Migration

  def change do
    create table(:account_user) do
      add(:account_id, references(:accounts, on_delete: :nothing), null: false)
      add(:user_id, references(:users, on_delete: :nothing), null: false)

      add(:created_at, :utc_datetime, null: false)
      add(:deleted_at, :utc_datetime)

      add(:performer_id, references(:annacl_performers, on_delete: :nothing), null: false)

      timestamps()
    end

    create(index(:account_user, [:created_at]))
    create(index(:account_user, [:deleted_at]))
  end
end
