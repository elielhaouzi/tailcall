defmodule Tailcall.Repo.Migrations.CreateSubscriptionsTable do
  use Ecto.Migration

  def change do
    create table(:subscriptions) do
      add(:account_id, :bigint, null: false)
      add(:customer_id, :bigint, null: false)

      # add(:billing_cycle_anchor, :utc_datetime, null: false)
      # add(:billing_thresholds_usage_gte, :integer, null: true)
      # add(:billing_thresholds_reset_billing_cycle_anchor, :boolean, null: true)
      add(:cancel_at, :utc_datetime, null: true)
      add(:cancel_at_period_end, :boolean, null: false)
      add(:cancellation_reason, :string, null: true)
      add(:canceled_at, :utc_datetime, null: true)

      add(:collection_method, :string, null: false)
      add(:created_at, :utc_datetime, null: false)
      add(:current_period_end, :utc_datetime, null: false)
      add(:current_period_start, :utc_datetime, null: false)
      # add(:days_until_due, :integer, null: true)
      # add(:default_payment_method_id, :integer, null: true)
      # add(:default_source_id, :integer, null: true)
      add(:ended_at, :utc_datetime, null: true)
      add(:livemode, :boolean, null: false)
      # add(:metadata, :map, null: true)
      # add(:pending_invoice_item_interval_interval, :string, null: true)
      # add(:pending_invoice_item_interval_interval_count, :string, null: true)
      add(:started_at, :utc_datetime, null: false)
      add(:status, :string, null: true)
      # add(:trial_end, :utc_datetime, null: true)
      # add(:trial_start, :utc_datetime, null: true)

      timestamps()
      add(:object, :string, default: "subscription")
    end

    create(index(:subscriptions, [:account_id]))
    create(index(:subscriptions, [:customer_id]))

    # create(index(:subscriptions, [:cancel_at]))
    create(index(:subscriptions, [:created_at]))
    create(index(:subscriptions, [:current_period_end]))
    create(index(:subscriptions, [:current_period_start]))
    create(index(:subscriptions, [:ended_at]))
    create(index(:subscriptions, [:livemode]))
    create(index(:subscriptions, [:started_at]))
    create(index(:subscriptions, [:status]))
    # create(index(:subscriptions, [:trial_end]))
    # create(index(:subscriptions, [:trial_start]))
  end
end
