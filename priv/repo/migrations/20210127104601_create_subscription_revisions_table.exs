defmodule Tailcall.Repo.Migrations.CreateSubscriptionRevisionsTable do
  use Ecto.Migration

  def change do
    # create table(:subscription_revisions) do
    #   add(:subscription_id, references(:subscriptions, type: :bigint, on_delete: :nothing),
    #     null: false
    #   )

    #   add(:billing_cycle_anchor, :utc_datetime, null: false)
    #   add(:cancel_at, :utc_datetime, null: true)
    #   add(:created_at, :utc_datetime, null: false)
    #   add(:current_period_end, :utc_datetime, null: false)
    #   add(:current_period_start, :utc_datetime, null: false)
    #   add(:ended_at, :utc_datetime, null: true)
    #   add(:livemode, :boolean, null: false)
    #   add(:started_at, :utc_datetime, null: false)
    #   add(:status, :string, null: true)
    #   add(:trial_end, :utc_datetime, null: true)
    #   add(:trial_start, :utc_datetime, null: true)

    #   timestamps()
    #   add(:object, :string, default: "subscription_revision")
    # end

    # create(index(:subscription_revisions, [:created_at]))
    # create(index(:subscription_revisions, [:current_period_end]))
    # create(index(:subscription_revisions, [:current_period_start]))
    # create(index(:subscription_revisions, [:ended_at]))
    # create(index(:subscription_revisions, [:livemode]))
    # create(index(:subscription_revisions, [:started_at]))
    # create(index(:subscription_revisions, [:status]))
    # create(index(:subscription_revisions, [:trial_end]))
    # create(index(:subscription_revisions, [:trial_start]))
  end
end
