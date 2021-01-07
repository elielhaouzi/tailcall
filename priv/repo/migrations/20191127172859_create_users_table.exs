defmodule Accounts.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:email, :string, null: false)
      add(:name, :string, null: true)
      add(:performer_id, references(:annacl_performers, on_delete: :nilify_all), null: false)

      timestamps()
      add(:object, :binary, default: "user")
    end

    create(unique_index(:users, [:email]))
    create(index(:users, [:inserted_at]))
  end
end
