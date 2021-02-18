defmodule Tailcall.Billing.SubscriptionsTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Billing.Invoices.Invoice

  alias Tailcall.Billing.Prices.Price

  alias Tailcall.Billing.Subscriptions
  alias Tailcall.Billing.Subscriptions.Subscription
  alias Tailcall.Billing.Subscriptions.Workers.RenewSubscriptionWorker
  alias Tailcall.Billing.Subscriptions.Workers.PastDueSubscriptionWorker

  @moduletag :subscriptions

  describe "list_subscriptions/1" do
    test "list subscriptions" do
      %{id: subscription_id} = insert!(:subscription)

      assert %{total: 1, data: [%{id: ^subscription_id}]} = Subscriptions.list_subscriptions()
    end

    test "order_by" do
      %{id: id1} = insert!(:subscription)
      %{id: id2} = insert!(:subscription)

      assert %{data: [%{id: ^id1}, %{id: ^id2}]} = Subscriptions.list_subscriptions()

      assert %{data: [%{id: ^id2}, %{id: ^id1}]} =
               Subscriptions.list_subscriptions(order_by_fields: [desc: :id])
    end

    test "filters" do
      subscription = insert!(:subscription)

      [
        [id: subscription.id],
        [id: [subscription.id]],
        [account_id: subscription.account_id],
        [customer_id: subscription.customer_id],
        [collection_method: subscription.collection_method],
        [livemode: subscription.livemode],
        [status: subscription.status]
      ]
      |> Enum.each(fn filter ->
        assert %{total: 1, data: [_price]} = Subscriptions.list_subscriptions(filters: filter)
      end)

      [
        [id: shortcode_id()],
        [account_id: shortcode_id()],
        [customer_id: shortcode_id()],
        [collection_method: "collection_method"],
        [livemode: !subscription.livemode],
        [status: "status"]
      ]
      |> Enum.each(fn filter ->
        assert %{total: 0, data: []} = Subscriptions.list_subscriptions(filters: filter)
      end)
    end

    test "includes" do
      account = insert!(:account)
      product = insert!(:product, account_id: account.id)

      price =
        build(:price, account_id: account.id, product_id: product.id)
        |> make_type_recurring(%{
          recurring_interval: Price.recurring_intervals().day,
          recurring_interval_count: 1
        })
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      customer = insert!(:customer, account_id: account.id)

      insert!(:subscription,
        account_id: account.id,
        customer_id: customer.id,
        items: [
          build(:subscription_item, price_id: price.id, quantity: 1)
        ]
      )

      %{data: [subscription], total: 1} = Subscriptions.list_subscriptions()
      assert Ecto.assoc_loaded?(subscription.items)
      assert Map.has_key?(subscription, :latest_invoice_id)
      refute Ecto.assoc_loaded?(subscription.latest_invoice)

      %{data: [subscription], total: 1} =
        Subscriptions.list_subscriptions(includes: [:latest_invoice])

      assert Ecto.assoc_loaded?(subscription.latest_invoice)
    end
  end

  describe "get_subscription/2" do
    test "returns the subscription" do
      %{id: id} = insert!(:subscription)
      assert %{id: ^id} = Subscriptions.get_subscription(id)
    end

    test "when the subscription does not exist, returns nil" do
      assert is_nil(Subscriptions.get_subscription(shortcode_id()))
    end

    test "includes" do
      account = insert!(:account)

      price = build(:price, account_id: account.id) |> insert!()

      customer = insert!(:customer, account_id: account.id)

      subscription_factory =
        insert!(:subscription,
          account_id: account.id,
          customer_id: customer.id,
          items: [
            build(:subscription_item, price_id: price.id, quantity: 1)
          ]
        )

      subscription = Subscriptions.get_subscription(subscription_factory.id)
      assert Ecto.assoc_loaded?(subscription.items)
      assert Map.has_key?(subscription, :latest_invoice_id)
      refute Ecto.assoc_loaded?(subscription.latest_invoice)

      subscription =
        Subscriptions.get_subscription(subscription_factory.id, includes: [:latest_invoice])

      assert Ecto.assoc_loaded?(subscription.items)
      assert Ecto.assoc_loaded?(subscription.latest_invoice)
    end
  end

  describe "get_subscription!/2" do
    test "returns the subscription" do
      %{id: id} = insert!(:subscription)
      assert %{id: ^id} = Subscriptions.get_subscription!(id)
    end

    test "when the subscription does not exist, raises a Ecto.NoResultsError" do
      assert_raise Ecto.NoResultsError, fn ->
        Subscriptions.get_subscription!(shortcode_id())
      end
    end
  end

  describe "create_subscription/1" do
    test "when price is licensed per_unit, creates a subscription" do
      account = insert!(:account)
      product = insert!(:product, account_id: account.id)

      price =
        build(:price, account_id: account.id, product_id: product.id)
        |> make_type_recurring(%{
          recurring_interval: Price.recurring_intervals().day,
          recurring_interval_count: 1
        })
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      customer = insert!(:customer, account_id: account.id)
      start_at = utc_now()

      assert {:ok, %Subscription{items: [subscription_item]} = subscription} =
               Subscriptions.create_subscription(%{
                 account_id: account.id,
                 customer_id: customer.id,
                 collection_method: Subscription.collection_methods().send_invoice,
                 livemode: price.livemode,
                 items: [%{price_id: price.id, quantity: 2}],
                 started_at: start_at
               })

      assert subscription.account_id == account.id
      assert subscription.customer_id == customer.id
      assert subscription.current_period_start == start_at

      assert subscription.current_period_end ==
               DateTime.add(subscription.current_period_start, 24 * 3600)

      assert subscription.collection_method == Subscription.collection_methods().send_invoice
      assert subscription.livemode == price.livemode
      assert subscription.status == Subscription.statuses().active

      assert subscription.latest_invoice_id == subscription.latest_invoice.id
      assert subscription.latest_invoice.account_id == subscription.account_id
      assert subscription.latest_invoice.customer_id == subscription.customer_id
      assert subscription.latest_invoice.subscription_id == subscription.id

      assert subscription.latest_invoice.billing_reason ==
               Invoice.billing_reasons().subscription_create

      assert subscription.latest_invoice.period_end == start_at
      assert subscription.latest_invoice.period_start == start_at
      assert subscription.latest_invoice.status == Invoice.statuses().draft
      assert subscription.latest_invoice.total == price.unit_amount * subscription_item.quantity

      assert_enqueued(
        worker: RenewSubscriptionWorker,
        args: %{id: subscription.id},
        scheduled_at: subscription.next_period_start
      )

      assert_enqueued(
        worker: PastDueSubscriptionWorker,
        args: %{subscription_id: subscription.id, invoice_id: subscription.latest_invoice.id},
        scheduled_at: subscription.latest_invoice.due_date
      )
    end

    test "when the create_subscription failed, does not enqueue a job" do
      assert {:error, _changeset} = Subscriptions.create_subscription(%{})
      refute_enqueued(worker: Tailcall.Billing.Subscriptions.Workers.RenewSubscriptionWorker)
      refute_enqueued(worker: Tailcall.Billing.Subscriptions.Workers.PastDueSubscriptionWorker)
    end

    test "when account does not exist, returns an error tuple with an invalid changeset" do
      customer = insert!(:customer)
      account_id = shortcode_id("acct")
      price = insert!(:price, account_id: account_id)

      subscription_params =
        params_for(:subscription,
          account_id: account_id,
          customer_id: customer.id,
          items: [build(:subscription_item, price_id: price.id)]
        )

      assert {:error, changeset} = Subscriptions.create_subscription(subscription_params)

      refute changeset.valid?
      assert %{account: ["does not exist"]} = errors_on(changeset)
    end

    test "when customer does not exist, returns an error tuple with an invalid changeset" do
      account = insert!(:account)

      price = insert!(:price, account_id: account.id)

      subscription_params =
        params_for(:subscription,
          account_id: account.id,
          customer_id: shortcode_id(),
          items: [build(:subscription_item, price_id: price.id)]
        )

      assert {:error, changeset} = Subscriptions.create_subscription(subscription_params)

      refute changeset.valid?
      assert %{customer: ["does not exist"]} = errors_on(changeset)
    end

    test "when customer does not belong to the account, returns an invalid changeset" do
      account = insert!(:account)
      customer = insert!(:customer)

      price = insert!(:price, account_id: account.id)

      subscription_params =
        params_for(:subscription,
          account_id: account.id,
          customer_id: customer.id,
          items: [build(:subscription_item, price_id: price.id)]
        )

      assert {:error, changeset} = Subscriptions.create_subscription(subscription_params)

      refute changeset.valid?
      assert %{customer: ["does not exist"]} = errors_on(changeset)
    end

    test "when price does not belong to the subscription account, returns an invalid changeset" do
      account = insert!(:account)
      customer = insert!(:customer, account_id: account.id)

      price = insert!(:price)

      subscription_params =
        params_for(:subscription,
          account_id: account.id,
          customer_id: customer.id,
          items: [build(:subscription_item, price_id: price.id)]
        )

      assert {:error, changeset} = Subscriptions.create_subscription(subscription_params)

      refute changeset.valid?

      assert %{items: ["prices must belongs to account #{account.id}"]} == errors_on(changeset)
    end

    test "when items' price are not with the same interval, returns an invalid changeset" do
      account = insert!(:account)
      customer = insert!(:customer, account_id: account.id)

      price_1 =
        insert!(:price,
          account_id: account.id,
          recurring_interval: Price.recurring_intervals().day
        )

      price_2 =
        insert!(:price,
          account_id: account.id,
          recurring_interval: Price.recurring_intervals().month
        )

      subscription_params =
        params_for(:subscription,
          account_id: account.id,
          customer_id: customer.id,
          items: [
            build(:subscription_item, price_id: price_1.id),
            build(:subscription_item, price_id: price_2.id)
          ]
        )

      assert {:error, changeset} = Subscriptions.create_subscription(subscription_params)

      refute changeset.valid?
      assert %{items: ["interval fields must match across all prices"]} = errors_on(changeset)
    end

    test "when items' price are not with the same interval count, returns an invalid changeset" do
      account = insert!(:account)
      customer = insert!(:customer, account_id: account.id)

      price_1 =
        insert!(:price,
          account_id: account.id,
          recurring_interval: Price.recurring_intervals().day,
          recurring_interval_count: 1
        )

      price_2 =
        insert!(:price,
          account_id: account.id,
          recurring_interval: Price.recurring_intervals().day,
          recurring_interval_count: 2
        )

      subscription_params =
        params_for(:subscription,
          account_id: account.id,
          customer_id: customer.id,
          items: [
            build(:subscription_item, price_id: price_1.id),
            build(:subscription_item, price_id: price_2.id)
          ]
        )

      assert {:error, changeset} = Subscriptions.create_subscription(subscription_params)

      refute changeset.valid?
      assert %{items: ["interval fields must match across all prices"]} = errors_on(changeset)
    end

    test "when items' price are not with the same currency, returns an invalid changeset" do
      account = insert!(:account)
      customer = insert!(:customer, account_id: account.id)

      price_1 = insert!(:price, account_id: account.id, currency: "ils")

      price_2 = insert!(:price, account_id: account.id, currency: "eur")

      subscription_params =
        params_for(:subscription,
          account_id: account.id,
          customer_id: customer.id,
          items: [
            build(:subscription_item, price_id: price_1.id),
            build(:subscription_item, price_id: price_2.id)
          ]
        )

      assert {:error, changeset} = Subscriptions.create_subscription(subscription_params)

      refute changeset.valid?
      assert %{items: ["currency must match across all prices"]} = errors_on(changeset)
    end
  end

  describe "renew_subscription/1" do
    test "when price is licensed per_unit and subscription is active, renew the subscription" do
      account = insert!(:account)
      product = insert!(:product, account_id: account.id)

      price =
        build(:price, account_id: account.id, product_id: product.id)
        |> make_type_recurring(%{
          recurring_interval: Price.recurring_intervals().day,
          recurring_interval_count: 1
        })
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      customer = insert!(:customer, account_id: account.id)
      utc_now = utc_now()
      start_at = utc_now |> add(-24 * 3600)
      end_at = utc_now

      subscription_factory =
        insert!(:subscription,
          account_id: account.id,
          customer_id: customer.id,
          current_period_end: end_at,
          current_period_start: start_at,
          collection_method: Subscription.collection_methods().send_invoice,
          items: [
            build(:subscription_item, price_id: price.id, quantity: 1, started_at: start_at)
          ],
          started_at: start_at,
          status: Subscription.statuses().active
        )

      assert {:ok, %Subscription{} = subscription} =
               Subscriptions.renew_subscription(subscription_factory)

      assert subscription.current_period_start == end_at

      assert subscription.current_period_end ==
               DateTime.add(subscription.current_period_start, 24 * 3600)

      assert subscription.status == Subscription.statuses().active

      assert subscription.latest_invoice_id == subscription.latest_invoice.id

      assert subscription.latest_invoice.billing_reason ==
               Invoice.billing_reasons().subscription_cycle

      assert subscription.latest_invoice.status == Invoice.statuses().draft
      assert subscription.latest_invoice.period_end == subscription_factory.current_period_end
      assert subscription.latest_invoice.period_start == subscription_factory.current_period_start
      assert %{line_items: [invoice_line_item]} = subscription.latest_invoice
      assert invoice_line_item.period_end == subscription.current_period_end
      assert invoice_line_item.period_start == subscription.current_period_start

      assert_enqueued(
        worker: RenewSubscriptionWorker,
        args: %{id: subscription.id},
        scheduled_at: subscription.next_period_start
      )
    end

    test "RenewSubscriptionWorker renew the subscription" do
      subscription = insert!(:subscription, status: Subscription.statuses().active)

      assert {:ok, _} = perform_job(RenewSubscriptionWorker, %{"id" => subscription.id})

      subscription_cycle_status = Invoice.billing_reasons().subscription_cycle

      assert %{latest_invoice: %{billing_reason: ^subscription_cycle_status}} =
               Subscriptions.get_subscription!(subscription.id,
                 includes: [:latest_invoice]
               )
    end
  end

  describe "cancel_subscription/2" do
    test "cancel at period end, cancel the subscription" do
      account = insert!(:account)
      product = insert!(:product, account_id: account.id)

      price =
        build(:price, account_id: account.id, product_id: product.id)
        |> make_type_recurring(%{
          recurring_interval: Price.recurring_intervals().day,
          recurring_interval_count: 1
        })
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      customer = insert!(:customer, account_id: account.id)
      utc_now = utc_now()
      start_at = utc_now |> add(-24 * 3600)
      end_at = utc_now

      subscription_factory =
        insert!(:subscription,
          account_id: account.id,
          customer_id: customer.id,
          current_period_end: end_at,
          current_period_start: start_at,
          collection_method: Subscription.collection_methods().send_invoice,
          items: [
            build(:subscription_item, price_id: price.id, quantity: 1, started_at: start_at)
          ],
          started_at: start_at,
          status: Subscription.statuses().active
        )

      Oban.insert!(
        RenewSubscriptionWorker.new(%{id: subscription_factory.id}, scheduled_at: end_at)
      )

      Oban.insert!(
        PastDueSubscriptionWorker.new(%{id: subscription_factory.id}, scheduled_at: end_at)
      )

      assert {:ok, %Subscription{} = subscription} =
               Subscriptions.cancel_subscription(subscription_factory, %{
                 cancel_at_period_end: true,
                 cancellation_reason: Subscription.cancellation_reasons().requested_by_customer
               })

      assert subscription.cancel_at_period_end == true
      assert subscription.cancel_at == subscription.current_period_end

      assert subscription.cancellation_reason ==
               Subscription.cancellation_reasons().requested_by_customer

      assert_in_delta DateTime.to_unix(subscription.canceled_at), DateTime.to_unix(utc_now()), 5

      assert [] =
               all_enqueued(
                 worker: RenewSubscriptionWorker,
                 args: %{id: subscription.id}
               )

      assert [_job] =
               all_enqueued(
                 worker: PastDueSubscriptionWorker,
                 args: %{id: subscription.id}
               )
    end
  end
end
