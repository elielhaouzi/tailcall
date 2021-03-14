defmodule Tailcall.Billing.SubscriptionsTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Billing.Invoices.Invoice

  alias Tailcall.Billing.Prices.Price
  alias Tailcall.Billing.InvoiceItems

  alias Tailcall.Billing.Subscriptions
  alias Tailcall.Billing.Subscriptions.Subscription
  alias Tailcall.Billing.Subscriptions.Workers.SubscriptionCycleWorker
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
    test "with prepaid items with licensed per_unit prices, 1.creates a subscription 2.create an invoice 3.enqueue subscription to subscription cycle worker 4.enqueue job for past due subscription" do
      account = insert!(:account)
      livemode = false

      price =
        build(:price, account_id: account.id, livemode: livemode)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
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
                 livemode: livemode,
                 items: [%{price_id: price.id, quantity: 2}],
                 started_at: start_at
               })

      assert subscription.account_id == account.id
      assert subscription.customer_id == customer.id
      assert subscription.current_period_start == start_at
      assert subscription.current_period_end == DateTime.add(start_at, 24 * 3600)
      assert subscription.collection_method == Subscription.collection_methods().send_invoice
      assert subscription.livemode == livemode
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
      assert [invoice_line_item] = subscription.latest_invoice.line_items
      assert invoice_line_item.period_start == subscription.current_period_start
      assert invoice_line_item.period_end == subscription.current_period_end
      assert invoice_line_item.subscription_item_id == subscription_item.id
      assert subscription_item.is_prepaid == true

      assert_enqueued(
        worker: SubscriptionCycleWorker,
        args: %{id: subscription.id},
        scheduled_at: subscription.next_period_start
      )

      assert_enqueued(
        worker: PastDueSubscriptionWorker,
        args: %{subscription_id: subscription.id, invoice_id: subscription.latest_invoice.id},
        scheduled_at: subscription.latest_invoice.due_date
      )
    end

    test "with postpaid items with licensed per_unit prices, 1.creates a subscription 2.create an invoice 3.enqueue job for renew" do
      account = insert!(:account)
      livemode = false

      price =
        build(:price, account_id: account.id, livemode: livemode)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
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
                 livemode: livemode,
                 items: [%{price_id: price.id, quantity: 2, is_prepaid: false}],
                 started_at: start_at
               })

      assert subscription.current_period_start == start_at
      assert subscription.current_period_end == DateTime.add(start_at, 24 * 3600)
      assert subscription.status == Subscription.statuses().active
      assert subscription.latest_invoice_id == nil
      assert subscription_item.is_prepaid == false

      assert_enqueued(
        worker: SubscriptionCycleWorker,
        args: %{id: subscription.id},
        scheduled_at: subscription.next_period_start
      )

      refute_enqueued(worker: PastDueSubscriptionWorker)
    end

    test "with prepaid and postpaid items with licensed per_unit prices, 1.creates a subscription 2.create an invoice 3.enqueue subscription to subscription cycle worker 4.enqueue job for past due subscription" do
      account = insert!(:account)
      livemode = false

      price_1 =
        build(:price, account_id: account.id, livemode: livemode)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      price_2 =
        build(:price, account_id: account.id, livemode: livemode)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      customer = insert!(:customer, account_id: account.id)

      start_at = utc_now()

      assert {:ok, %Subscription{items: subscription_items} = subscription} =
               Subscriptions.create_subscription(%{
                 account_id: account.id,
                 customer_id: customer.id,
                 collection_method: Subscription.collection_methods().send_invoice,
                 livemode: livemode,
                 items: [
                   %{price_id: price_1.id, quantity: 2, is_prepaid: true},
                   %{price_id: price_2.id, quantity: 2, is_prepaid: false}
                 ],
                 started_at: start_at
               })

      subscription_item_prepaid = subscription_items |> Enum.find(& &1.is_prepaid)
      _subscription_item_postpaid = subscription_items |> Enum.find(&(!&1.is_prepaid))

      assert subscription.current_period_start == start_at
      assert subscription.current_period_end == DateTime.add(start_at, 24 * 3600)
      assert subscription.status == Subscription.statuses().active
      assert subscription.latest_invoice_id == subscription.latest_invoice.id

      assert subscription.latest_invoice.billing_reason ==
               Invoice.billing_reasons().subscription_create

      assert subscription.latest_invoice.period_end == start_at
      assert subscription.latest_invoice.period_start == start_at
      assert subscription.latest_invoice.status == Invoice.statuses().draft
      assert [invoice_line_item] = subscription.latest_invoice.line_items
      assert invoice_line_item.period_start == subscription.current_period_start
      assert invoice_line_item.period_end == subscription.current_period_end
      assert invoice_line_item.subscription_item_id == subscription_item_prepaid.id

      assert_enqueued(
        worker: SubscriptionCycleWorker,
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
      refute_enqueued(worker: Tailcall.Billing.Subscriptions.Workers.SubscriptionCycleWorker)
      refute_enqueued(worker: Tailcall.Billing.Subscriptions.Workers.PastDueSubscriptionWorker)
    end

    test "when account does not exist, returns an error tuple with an invalid changeset" do
      subscription_params = params_for(:subscription, account_id: shortcode_id("acct"))

      assert {:error, changeset} = Subscriptions.create_subscription(subscription_params)

      refute changeset.valid?
      assert %{account: ["does not exist"]} = errors_on(changeset)
    end

    test "when customer does not exist, returns an error tuple with an invalid changeset" do
      subscription_params = params_for(:subscription, customer_id: shortcode_id())

      assert {:error, changeset} = Subscriptions.create_subscription(subscription_params)

      refute changeset.valid?
      assert %{customer: ["does not exist"]} = errors_on(changeset)
    end

    test "when customer does not belong to the account, returns an invalid changeset" do
      account = insert!(:account)
      customer = insert!(:customer)

      subscription_params =
        params_for(:subscription, account_id: account.id, customer_id: customer.id)

      assert {:error, changeset} = Subscriptions.create_subscription(subscription_params)

      refute changeset.valid?
      assert %{customer: ["does not exist"]} = errors_on(changeset)
    end

    test "with no items, returns an invalid changeset" do
      account = insert!(:account)

      subscription_params = params_for(:subscription, account_id: account.id, items: [])

      assert {:error, changeset} = Subscriptions.create_subscription(subscription_params)

      refute changeset.valid?
      assert %{items: ["can't be blank"]} = errors_on(changeset)
    end

    test "when price of the items are not with the same interval, returns an invalid changeset" do
      account = insert!(:account)

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
          items: [
            build(:subscription_item, price_id: price_1.id),
            build(:subscription_item, price_id: price_2.id)
          ]
        )

      assert {:error, changeset} = Subscriptions.create_subscription(subscription_params)

      refute changeset.valid?
      assert %{items: ["interval fields must match across all prices"]} = errors_on(changeset)
    end

    test "when price of the items are not with the same interval count, returns an invalid changeset" do
      account = insert!(:account)

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
          items: [
            build(:subscription_item, price_id: price_1.id),
            build(:subscription_item, price_id: price_2.id)
          ]
        )

      assert {:error, changeset} = Subscriptions.create_subscription(subscription_params)

      refute changeset.valid?
      assert %{items: ["interval fields must match across all prices"]} = errors_on(changeset)
    end

    test "when price of the items are not with the same currency, returns an invalid changeset" do
      account = insert!(:account)

      price_1 = insert!(:price, account_id: account.id, currency: "ils")

      price_2 = insert!(:price, account_id: account.id, currency: "eur")

      subscription_params =
        params_for(:subscription,
          account_id: account.id,
          items: [
            build(:subscription_item, price_id: price_1.id),
            build(:subscription_item, price_id: price_2.id)
          ]
        )

      assert {:error, changeset} = Subscriptions.create_subscription(subscription_params)

      refute changeset.valid?
      assert %{items: ["currency must match across all prices"]} = errors_on(changeset)
    end

    test "when the same price is on multiple items, returns an invalid changeset" do
      account = insert!(:account)

      price = insert!(:price, account_id: account.id)

      subscription_params =
        params_for(:subscription,
          account_id: account.id,
          items: [
            build(:subscription_item, price_id: price.id),
            build(:subscription_item, price_id: price.id)
          ]
        )

      assert {:error, changeset} = Subscriptions.create_subscription(subscription_params)

      refute changeset.valid?

      assert %{items: ["cannot add multiple subscription items with the same price"]} ==
               errors_on(changeset)
    end

    test "when price of the items are not with the same livemode than the subscription, returns an invalid changeset" do
      account = insert!(:account)

      price = insert!(:price, account_id: account.id, livemode: true)

      subscription_params =
        params_for(:subscription,
          account_id: account.id,
          livemode: false,
          items: [build(:subscription_item, price_id: price.id)]
        )

      assert {:error, changeset} = Subscriptions.create_subscription(subscription_params)

      refute changeset.valid?
      assert %{items: [%{price_id: ["does not exist"]}]} = errors_on(changeset)
    end
  end

  describe "renew_subscription/1" do
    test "for prepaid item with licensed per_unit price and subscription is active, renew the subscription for the next period" do
      account = insert!(:account)

      price =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
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
            build(:subscription_item, price_id: price.id, quantity: 1, created_at: start_at)
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
      assert subscription.latest_invoice.period_start == subscription.last_period_start
      assert subscription.latest_invoice.period_end == subscription.last_period_end
      assert %{line_items: [invoice_line_item]} = subscription.latest_invoice
      assert invoice_line_item.period_end == subscription.current_period_end
      assert invoice_line_item.period_start == subscription.current_period_start

      assert_enqueued(
        worker: SubscriptionCycleWorker,
        args: %{id: subscription.id},
        scheduled_at: subscription.next_period_start
      )

      assert_enqueued(
        worker: PastDueSubscriptionWorker,
        args: %{subscription_id: subscription.id, invoice_id: subscription.latest_invoice.id},
        scheduled_at: subscription.latest_invoice.due_date
      )
    end

    test "for postpaid item with licensed per_unit price and subscription is active, renew the subscription for the next period" do
      account = insert!(:account)

      price =
        build(:price, account_id: account.id)
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
            build(:subscription_item,
              is_prepaid: false,
              price_id: price.id,
              quantity: 1,
              created_at: start_at
            )
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

      assert_in_delta DateTime.to_unix(subscription.latest_invoice.created_at),
                      DateTime.to_unix(utc_now),
                      5

      assert subscription.latest_invoice.status == Invoice.statuses().draft
      assert subscription.latest_invoice.period_end == subscription.last_period_end
      assert subscription.latest_invoice.period_start == subscription.last_period_start
      assert %{line_items: [invoice_line_item]} = subscription.latest_invoice
      assert invoice_line_item.period_end == subscription.last_period_end
      assert invoice_line_item.period_start == subscription.last_period_start
    end

    test "for prepaid and postpaid items with licensed per_unit price, renew the subscription for the next period" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      price_2 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
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
            build(:subscription_item,
              is_prepaid: true,
              price_id: price_1.id,
              quantity: 1,
              created_at: start_at
            ),
            build(:subscription_item,
              is_prepaid: false,
              price_id: price_2.id,
              quantity: 1,
              created_at: start_at
            )
          ],
          started_at: start_at,
          status: Subscription.statuses().active
        )

      assert {:ok, %Subscription{items: subscription_items} = subscription} =
               Subscriptions.renew_subscription(subscription_factory)

      subscription_item_prepaid = subscription_items |> Enum.find(& &1.is_prepaid)
      subscription_item_postpaid = subscription_items |> Enum.find(&(!&1.is_prepaid))

      assert subscription.latest_invoice.period_start == subscription.last_period_start
      assert subscription.latest_invoice.period_end == subscription.last_period_end
      assert %{line_items: invoice_line_items} = subscription.latest_invoice
      invoice_line_item_prepaid = invoice_line_items |> Enum.find(&(&1.price_id == price_1.id))
      invoice_line_item_postpaid = invoice_line_items |> Enum.find(&(&1.price_id == price_2.id))

      assert invoice_line_item_prepaid.subscription_item_id == subscription_item_prepaid.id
      assert invoice_line_item_prepaid.period_end == subscription.current_period_end
      assert invoice_line_item_prepaid.period_start == subscription.current_period_start

      assert invoice_line_item_postpaid.subscription_item_id == subscription_item_postpaid.id
      assert invoice_line_item_postpaid.period_end == subscription.last_period_end
      assert invoice_line_item_postpaid.period_start == subscription.last_period_start
    end

    test "SubscriptionCycleWorker renew the subscription" do
      subscription =
        insert!(:subscription,
          status: Subscription.statuses().active,
          collection_method: Subscription.collection_methods().send_invoice
        )

      assert {:ok, _} = perform_job(SubscriptionCycleWorker, %{"id" => subscription.id})

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
            build(:subscription_item, price_id: price.id, quantity: 1, created_at: start_at)
          ],
          started_at: start_at,
          status: Subscription.statuses().active
        )

      Oban.insert!(
        SubscriptionCycleWorker.new(%{id: subscription_factory.id}, scheduled_at: end_at)
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

      assert [] = all_enqueued(worker: SubscriptionCycleWorker, args: %{id: subscription.id})

      assert [_job] =
               all_enqueued(worker: PastDueSubscriptionWorker, args: %{id: subscription.id})
    end
  end

  describe "update_subscription/2" do
    test "update a quantity with proration of a prepaid item with licensed per_unit price, 1.updates the subscription 2.creates invoice_items for prorata, returns the subscription" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      %{items: [subscription_item_1_factory, subscription_item_2_factory]} =
        subscription_factory =
        insert!(:subscription,
          account_id: account.id,
          items: [
            build(:subscription_item,
              account_id: account.id,
              quantity: 1,
              price_id: price_1.id,
              price: price_1,
              is_prepaid: true
            ),
            build(:subscription_item, account_id: account.id)
          ]
        )

      proration_date = utc_now() |> add(8 * 3600)

      new_quantity = subscription_item_1_factory.quantity + 1

      assert {:ok, %Subscription{items: subscription_items} = subscription} =
               Subscriptions.update_subscription(subscription_factory, %{
                 items: [
                   %{id: subscription_item_1_factory.id, quantity: new_quantity}
                 ],
                 proration_behavior: Subscription.proration_behaviors().create_proration,
                 proration_date: proration_date
               })

      assert subscription.current_period_start == subscription_factory.current_period_start
      assert subscription.current_period_end == subscription_factory.current_period_end

      subscription_item_1 =
        subscription_items |> Enum.find(&(&1.id == subscription_item_1_factory.id))

      subscription_item_2 =
        subscription_items |> Enum.find(&(&1.id == subscription_item_2_factory.id))

      assert subscription_item_2.id == subscription_item_2_factory.id
      assert subscription_item_2.quantity == subscription_item_2_factory.quantity
      assert subscription_item_2.price_id == subscription_item_2_factory.price_id
      assert subscription_item_2.updated_at == subscription_item_2_factory.updated_at

      assert subscription_item_1.quantity == new_quantity
      assert subscription_item_1.price_id == subscription_item_1_factory.price_id

      billing_period_in_seconds =
        DateTime.diff(subscription.current_period_end, subscription.current_period_start)

      credit_unused_time =
        subscription.current_period_end
        |> DateTime.diff(proration_date)
        |> Kernel.*(100)
        |> Decimal.div(billing_period_in_seconds)
        |> Decimal.mult(
          subscription_item_1_factory.price.unit_amount * subscription_item_1_factory.quantity
        )
        |> Decimal.div(100)
        |> Decimal.round()
        |> Decimal.to_integer()

      debit_remaining_time =
        subscription.current_period_end
        |> DateTime.diff(proration_date)
        |> Kernel.*(100)
        |> Decimal.div(billing_period_in_seconds)
        |> Decimal.mult(subscription_item_1.price.unit_amount * subscription_item_1.quantity)
        |> Decimal.div(100)
        |> Decimal.round()
        |> Decimal.to_integer()

      assert %{data: [debit_invoice_item, credit_invoice_item]} =
               InvoiceItems.list_invoice_items(filter: [subscription_id: subscription.id])

      assert credit_invoice_item.amount == -credit_unused_time
      assert credit_invoice_item.is_proration
      assert credit_invoice_item.subscription_item_id == subscription_item_1.id
      assert credit_invoice_item.period_start == proration_date
      assert credit_invoice_item.period_end == subscription.current_period_end

      assert debit_invoice_item.amount == debit_remaining_time
      assert debit_invoice_item.is_proration
      assert debit_invoice_item.subscription_item_id == subscription_item_1.id
      assert debit_invoice_item.period_start == proration_date
      assert debit_invoice_item.period_end == subscription.current_period_end
    end

    test "update a quantity without proration of a prepaid item with licensed per_unit price, updates the subscription without creating invoice_items" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      %{items: [subscription_item_factory]} =
        subscription_factory =
        insert!(:subscription,
          account_id: account.id,
          items: [
            build(:subscription_item,
              account_id: account.id,
              quantity: 1,
              price_id: price_1.id,
              is_prepaid: true
            )
          ]
        )

      new_quantity = subscription_item_factory.quantity + 1

      assert {:ok, %Subscription{items: [subscription_item]} = subscription} =
               Subscriptions.update_subscription(subscription_factory, %{
                 items: [
                   %{
                     id: subscription_item_factory.id,
                     quantity: new_quantity
                   }
                 ],
                 proration_behavior: Subscription.proration_behaviors().none
               })

      assert subscription.current_period_start == subscription_factory.current_period_start
      assert subscription.current_period_end == subscription_factory.current_period_end

      assert subscription_item.quantity == new_quantity
      assert subscription_item.price_id == subscription_item_factory.price_id

      assert %{data: []} =
               InvoiceItems.list_invoice_items(filter: [subscription_id: subscription.id])
    end

    test "update a quantity with proration of a postpaid item with licensed per_unit price, 1.updates the subscription 2.creates invoice_items for prorata, returns the subscription" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      %{items: [subscription_item_1_factory, subscription_item_2_factory]} =
        subscription_factory =
        insert!(:subscription,
          account_id: account.id,
          items: [
            build(:subscription_item,
              account_id: account.id,
              quantity: 1,
              price_id: price_1.id,
              price: price_1,
              is_prepaid: false
            ),
            build(:subscription_item, account_id: account.id)
          ]
        )

      proration_date = utc_now() |> add(8 * 3600)

      new_quantity = subscription_item_1_factory.quantity + 1

      assert {:ok, %Subscription{items: subscription_items} = subscription} =
               Subscriptions.update_subscription(subscription_factory, %{
                 items: [
                   %{id: subscription_item_1_factory.id, quantity: new_quantity}
                 ],
                 proration_behavior: Subscription.proration_behaviors().create_proration,
                 proration_date: proration_date
               })

      assert subscription.current_period_start == subscription_factory.current_period_start
      assert subscription.current_period_end == subscription_factory.current_period_end

      subscription_item_1 =
        subscription_items |> Enum.find(&(&1.id == subscription_item_1_factory.id))

      subscription_item_2 =
        subscription_items |> Enum.find(&(&1.id == subscription_item_2_factory.id))

      assert subscription_item_2.id == subscription_item_2_factory.id
      assert subscription_item_2.quantity == subscription_item_2_factory.quantity
      assert subscription_item_2.price_id == subscription_item_2_factory.price_id
      assert subscription_item_2.updated_at == subscription_item_2_factory.updated_at

      assert subscription_item_1.quantity == new_quantity
      assert subscription_item_1.price_id == subscription_item_1_factory.price_id

      billing_period_in_seconds =
        DateTime.diff(subscription.current_period_end, subscription.current_period_start)

      credit_unused_time =
        proration_date
        |> DateTime.diff(subscription.current_period_start)
        |> Kernel.*(100)
        |> Decimal.div(billing_period_in_seconds)
        |> Decimal.mult(
          subscription_item_1_factory.price.unit_amount * subscription_item_1.quantity
        )
        |> Decimal.div(100)
        |> Decimal.round()
        |> Decimal.to_integer()

      debit_remaining_time =
        proration_date
        |> DateTime.diff(subscription.current_period_start)
        |> Kernel.*(100)
        |> Decimal.div(billing_period_in_seconds)
        |> Decimal.mult(
          subscription_item_1.price.unit_amount * subscription_item_1_factory.quantity
        )
        |> Decimal.div(100)
        |> Decimal.round()
        |> Decimal.to_integer()

      assert %{data: [debit_invoice_item, credit_invoice_item]} =
               InvoiceItems.list_invoice_items(filter: [subscription_id: subscription.id])

      assert credit_invoice_item.amount == -credit_unused_time
      assert credit_invoice_item.is_proration
      assert credit_invoice_item.subscription_item_id == subscription_item_1.id
      assert credit_invoice_item.period_start == subscription.current_period_start
      assert credit_invoice_item.period_end == proration_date

      assert debit_invoice_item.amount == debit_remaining_time
      assert debit_invoice_item.is_proration
      assert debit_invoice_item.subscription_item_id == subscription_item_1.id
      assert debit_invoice_item.period_start == subscription.current_period_start
      assert debit_invoice_item.period_end == proration_date
    end

    test "update a quantity without proration of a postpaid item with licensed per_unit price, updates the subscription without creating invoice_items and returns the subscription" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      %{items: [subscription_item_factory]} =
        subscription_factory =
        insert!(:subscription,
          account_id: account.id,
          items: [
            build(:subscription_item,
              account_id: account.id,
              quantity: 1,
              price_id: price_1.id,
              price: price_1,
              is_prepaid: true
            )
          ]
        )

      new_quantity = subscription_item_factory.quantity + 1

      assert {:ok, %Subscription{items: [subscription_item]} = subscription} =
               Subscriptions.update_subscription(subscription_factory, %{
                 items: [
                   %{id: subscription_item_factory.id, quantity: new_quantity}
                 ],
                 proration_behavior: Subscription.proration_behaviors().none
               })

      assert subscription.current_period_start == subscription_factory.current_period_start
      assert subscription.current_period_end == subscription_factory.current_period_end

      assert subscription_item.quantity == new_quantity
      assert subscription_item.price_id == subscription_item_factory.price_id

      assert %{data: []} =
               InvoiceItems.list_invoice_items(filter: [subscription_id: subscription.id])
    end

    test "update with a price with the same interval fields with proration of a prepaid item with licensed per_unit price, 1.updates the subscription 2.creates invoice_items for prorata, returns the subscription" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit(%{unit_amount: 1_000})
        |> insert!()

      price_2 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit(%{unit_amount: 2_000})
        |> insert!()

      %{items: [subscription_item_factory]} =
        subscription =
        insert!(:subscription,
          account_id: account.id,
          items: [
            build(:subscription_item,
              account_id: account.id,
              price_id: price_1.id,
              price: price_1,
              quantity: 2
            )
          ]
        )

      proration_date = utc_now() |> add(8 * 3600)

      assert {:ok, %Subscription{items: [subscription_item]} = subscription} =
               Subscriptions.update_subscription(subscription, %{
                 items: [%{id: subscription_item_factory.id, price_id: price_2.id}],
                 proration_behavior: Subscription.proration_behaviors().create_proration,
                 proration_date: proration_date
               })

      assert subscription_item.price_id == price_2.id
      assert subscription_item.quantity == subscription_item_factory.quantity

      billing_period_in_seconds =
        DateTime.diff(subscription.current_period_end, subscription.current_period_start)

      credit_unused_time =
        subscription.current_period_end
        |> DateTime.diff(proration_date)
        |> Kernel.*(100)
        |> Decimal.div(billing_period_in_seconds)
        |> Decimal.mult(
          subscription_item_factory.price.unit_amount * subscription_item_factory.quantity
        )
        |> Decimal.div(100)
        |> Decimal.round()
        |> Decimal.to_integer()

      debit_remaining_time =
        subscription.current_period_end
        |> DateTime.diff(proration_date)
        |> Kernel.*(100)
        |> Decimal.div(billing_period_in_seconds)
        |> Decimal.mult(subscription_item.price.unit_amount * subscription_item.quantity)
        |> Decimal.div(100)
        |> Decimal.round()
        |> Decimal.to_integer()

      assert %{data: [debit_invoice_item, credit_invoice_item]} =
               InvoiceItems.list_invoice_items(filter: [subscription_id: subscription.id])

      assert credit_invoice_item.amount == -credit_unused_time
      assert credit_invoice_item.is_proration
      assert credit_invoice_item.subscription_item_id == subscription_item.id
      assert credit_invoice_item.period_start == proration_date
      assert credit_invoice_item.period_end == subscription.current_period_end

      assert debit_invoice_item.amount == debit_remaining_time
      assert debit_invoice_item.is_proration
      assert debit_invoice_item.subscription_item_id == subscription_item.id
      assert debit_invoice_item.period_start == proration_date
      assert debit_invoice_item.period_end == subscription.current_period_end
    end

    test "update with a price with the same interval fields without proration of a prepaid item with licensed per_unit price, updates the subscription without creating invoice_items" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit(%{unit_amount: 1_000})
        |> insert!()

      price_2 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit(%{unit_amount: 2_000})
        |> insert!()

      %{items: [subscription_item_factory]} =
        subscription =
        insert!(:subscription,
          account_id: account.id,
          items: [
            build(:subscription_item,
              account_id: account.id,
              price_id: price_1.id,
              price: price_1,
              quantity: 2
            )
          ]
        )

      assert {:ok, %Subscription{items: [subscription_item]} = subscription} =
               Subscriptions.update_subscription(subscription, %{
                 items: [
                   %{id: subscription_item_factory.id, is_deleted: false, price_id: price_2.id}
                 ],
                 proration_behavior: Subscription.proration_behaviors().none
               })

      assert subscription_item.price_id == price_2.id
      assert subscription_item.quantity == subscription_item_factory.quantity

      assert %{data: []} =
               InvoiceItems.list_invoice_items(filter: [subscription_id: subscription.id])
    end

    test "update with a price with the same interval fields with proration of a postpaid item with licensed per_unit price, 1.updates the subscription 2.creates invoice_items for prorata, returns the subscription" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit(%{unit_amount: 1_000})
        |> insert!()

      price_2 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit(%{unit_amount: 2_000})
        |> insert!()

      %{items: [subscription_item_factory]} =
        subscription =
        insert!(:subscription,
          account_id: account.id,
          items: [
            build(:subscription_item,
              account_id: account.id,
              is_prepaid: false,
              price_id: price_1.id,
              price: price_1,
              quantity: 2
            )
          ]
        )

      proration_date = utc_now() |> add(8 * 3600)

      assert {:ok, %Subscription{items: [subscription_item]} = subscription} =
               Subscriptions.update_subscription(subscription, %{
                 items: [%{id: subscription_item_factory.id, price_id: price_2.id}],
                 proration_behavior: Subscription.proration_behaviors().create_proration,
                 proration_date: proration_date
               })

      assert subscription_item.price_id == price_2.id
      assert subscription_item.quantity == subscription_item_factory.quantity

      billing_period_in_seconds =
        DateTime.diff(subscription.current_period_end, subscription.current_period_start)

      credit_unused_time =
        proration_date
        |> DateTime.diff(subscription.current_period_start)
        |> Kernel.*(100)
        |> Decimal.div(billing_period_in_seconds)
        |> Decimal.mult(subscription_item.price.unit_amount * subscription_item.quantity)
        |> Decimal.div(100)
        |> Decimal.round()
        |> Decimal.to_integer()

      debit_remaining_time =
        proration_date
        |> DateTime.diff(subscription.current_period_start)
        |> Kernel.*(100)
        |> Decimal.div(billing_period_in_seconds)
        |> Decimal.mult(
          subscription_item_factory.price.unit_amount * subscription_item_factory.quantity
        )
        |> Decimal.div(100)
        |> Decimal.round()
        |> Decimal.to_integer()

      assert %{data: [debit_invoice_item, credit_invoice_item]} =
               InvoiceItems.list_invoice_items(filter: [subscription_id: subscription.id])

      assert credit_invoice_item.amount == -credit_unused_time
      assert credit_invoice_item.is_proration
      assert credit_invoice_item.subscription_item_id == subscription_item.id
      assert credit_invoice_item.period_start == subscription.current_period_start
      assert credit_invoice_item.period_end == proration_date

      assert debit_invoice_item.amount == debit_remaining_time
      assert debit_invoice_item.is_proration
      assert debit_invoice_item.subscription_item_id == subscription_item.id
      assert debit_invoice_item.period_start == subscription.current_period_start
      assert debit_invoice_item.period_end == proration_date
    end

    test "update with a price with the same interval fields without proration of a postpaid item with licensed per_unit price, updates the subscription without creating invoice_items and returns the subscription" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit(%{unit_amount: 1_000})
        |> insert!()

      price_2 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit(%{unit_amount: 2_000})
        |> insert!()

      %{items: [subscription_item_factory]} =
        subscription =
        insert!(:subscription,
          account_id: account.id,
          items: [
            build(:subscription_item,
              account_id: account.id,
              is_prepaid: false,
              price_id: price_1.id,
              price: price_1,
              quantity: 2
            )
          ]
        )

      assert {:ok, %Subscription{items: [subscription_item]} = subscription} =
               Subscriptions.update_subscription(subscription, %{
                 items: [%{id: subscription_item_factory.id, price_id: price_2.id}],
                 proration_behavior: Subscription.proration_behaviors().none
               })

      assert subscription_item.price_id == price_2.id
      assert subscription_item.quantity == subscription_item_factory.quantity

      assert %{data: []} =
               InvoiceItems.list_invoice_items(filter: [subscription_id: subscription.id])
    end

    test "delete prepaid item with proration, updates the subscription, creates an invoice item and return the subscription" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      %{items: [subscription_item_1_factory, subscription_item_2_factory]} =
        subscription_factory =
        insert!(:subscription,
          account_id: account.id,
          items: [
            build(:subscription_item,
              account_id: account.id,
              quantity: 1,
              price_id: price_1.id,
              price: price_1,
              is_prepaid: true
            ),
            build(:subscription_item, account_id: account.id)
          ]
        )

      proration_date = utc_now() |> add(8 * 3600)

      assert {:ok, %Subscription{items: [subscription_item]} = subscription} =
               Subscriptions.update_subscription(subscription_factory, %{
                 items: [%{id: subscription_item_1_factory.id, is_deleted: true}],
                 proration_behavior: Subscription.proration_behaviors().create_proration,
                 proration_date: proration_date
               })

      assert subscription_item.id == subscription_item_2_factory.id

      billing_period_in_seconds =
        DateTime.diff(subscription.current_period_end, subscription.current_period_start)

      credit_unused_time =
        subscription.current_period_end
        |> DateTime.diff(proration_date)
        |> Kernel.*(100)
        |> Decimal.div(billing_period_in_seconds)
        |> Decimal.mult(
          subscription_item_2_factory.price.unit_amount * subscription_item_1_factory.quantity
        )
        |> Decimal.div(100)
        |> Decimal.round()
        |> Decimal.to_integer()

      assert %{data: [credit_invoice_item]} =
               InvoiceItems.list_invoice_items(filter: [subscription_id: subscription.id])

      assert credit_invoice_item.amount == -credit_unused_time
      assert credit_invoice_item.is_proration
      assert credit_invoice_item.subscription_item_id == subscription_item_1_factory.id
      assert credit_invoice_item.period_start == proration_date
      assert credit_invoice_item.period_end == subscription.current_period_end
    end

    test "delete prepaid item without proration, updates the subscription" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      %{items: [subscription_item_1_factory, subscription_item_2_factory]} =
        subscription_factory =
        insert!(:subscription,
          account_id: account.id,
          items: [
            build(:subscription_item,
              account_id: account.id,
              quantity: 1,
              price_id: price_1.id,
              is_prepaid: true
            ),
            build(:subscription_item, account_id: account.id)
          ]
        )

      assert {:ok, %Subscription{items: [subscription_item]} = subscription} =
               Subscriptions.update_subscription(subscription_factory, %{
                 items: [%{id: subscription_item_1_factory.id, is_deleted: true}],
                 proration_behavior: Subscription.proration_behaviors().none
               })

      assert subscription_item.id == subscription_item_2_factory.id

      assert %{data: []} =
               InvoiceItems.list_invoice_items(filter: [subscription_id: subscription.id])
    end

    test "delete postpaid item with proration, updates the subscription, creates an invoice item and return the subscription" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      %{items: [subscription_item_1_factory, subscription_item_2_factory]} =
        subscription_factory =
        insert!(:subscription,
          account_id: account.id,
          items: [
            build(:subscription_item,
              is_prepaid: false,
              account_id: account.id,
              quantity: 1,
              price_id: price_1.id,
              price: price_1
            ),
            build(:subscription_item, account_id: account.id)
          ]
        )

      proration_date = utc_now() |> add(8 * 3600)

      assert {:ok, %Subscription{items: [subscription_item]} = subscription} =
               Subscriptions.update_subscription(subscription_factory, %{
                 items: [%{id: subscription_item_1_factory.id, is_deleted: true}],
                 proration_behavior: Subscription.proration_behaviors().create_proration,
                 proration_date: proration_date
               })

      assert subscription_item.id == subscription_item_2_factory.id

      billing_period_in_seconds =
        DateTime.diff(subscription.current_period_end, subscription.current_period_start)

      debit_amount =
        proration_date
        |> DateTime.diff(subscription.current_period_start)
        |> Kernel.*(100)
        |> Decimal.div(billing_period_in_seconds)
        |> Decimal.mult(
          subscription_item_1_factory.price.unit_amount * subscription_item_1_factory.quantity
        )
        |> Decimal.div(100)
        |> Decimal.round()
        |> Decimal.to_integer()

      assert %{data: [debit_invoice_item]} =
               InvoiceItems.list_invoice_items(filter: [subscription_id: subscription.id])

      assert debit_invoice_item.amount == debit_amount
      assert debit_invoice_item.is_proration
      assert debit_invoice_item.subscription_item_id == subscription_item_1_factory.id
      assert debit_invoice_item.period_start == subscription.current_period_start
      assert debit_invoice_item.period_end == proration_date
    end

    test "delete postpaid item without proration, updates the subscription without creating an invoice item and return the subscription" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      %{items: [subscription_item_1_factory, subscription_item_2_factory]} =
        subscription_factory =
        insert!(:subscription,
          account_id: account.id,
          items: [
            build(:subscription_item,
              is_prepaid: false,
              account_id: account.id,
              quantity: 1,
              price_id: price_1.id,
              price: price_1
            ),
            build(:subscription_item, account_id: account.id)
          ]
        )

      assert {:ok, %Subscription{items: [subscription_item]} = subscription} =
               Subscriptions.update_subscription(subscription_factory, %{
                 items: [%{id: subscription_item_1_factory.id, is_deleted: true}],
                 proration_behavior: Subscription.proration_behaviors().none
               })

      assert subscription_item.id == subscription_item_2_factory.id

      assert %{data: []} =
               InvoiceItems.list_invoice_items(filter: [subscription_id: subscription.id])
    end

    test "delete item when no others items remains, returns an invalid changeset" do
      account = insert!(:account)

      %{items: [subscription_item_1_factory]} =
        subscription_factory =
        insert!(:subscription,
          account_id: account.id,
          items: [
            build(:subscription_item, account_id: account.id)
          ]
        )

      assert {:error, changeset} =
               Subscriptions.update_subscription(subscription_factory, %{
                 items: [%{id: subscription_item_1_factory.id, is_deleted: true}],
                 proration_behavior: Subscription.proration_behaviors().none
               })

      refute changeset.valid?

      assert %{items: ["must have at least one active price"]} = errors_on(changeset)
    end

    # test "adding an prepaid item with proration with a licensed per_unit price, updates the subscription without creating invoice_items" do
    #   account = insert!(:account)

    #   price =
    #     build(:price, account_id: account.id)
    #     |> make_type_recurring()
    #     |> make_recurring_interval_per_day()
    #     |> make_recurring_usage_type_licensed()
    #     |> make_billing_scheme_per_unit()
    #     |> insert!()

    #   %{items: [subscription_item_factory]} =
    #     subscription_factory =
    #     insert!(:subscription,
    #       account_id: account.id,
    #       items: [build(:subscription_item, account_id: account.id)]
    #     )

    #   proration_date = utc_now() |> add(8 * 3600)

    #   assert {:ok, %Subscription{items: subscription_items} = subscription} =
    #            Subscriptions.update_subscription(subscription_factory, %{
    #              items: [%{price_id: price.id}],
    #              proration_behavior: Subscription.proration_behaviors().create_proration,
    #              proration_date: proration_date
    #            })

    #   assert subscription.current_period_start == subscription_factory.current_period_start
    #   assert subscription.current_period_end == subscription_factory.current_period_end

    #   subscription_item_1 =
    #     subscription_items |> Enum.find(&(&1.id == subscription_item_factory.id))

    #   subscription_item_2 =
    #     subscription_items |> Enum.find(&(&1.id != subscription_item_factory.id))

    #   assert subscription_item_1.id == subscription_item_factory.id
    #   assert subscription_item_1.quantity == subscription_item_factory.quantity
    #   assert subscription_item_1.price_id == subscription_item_factory.price_id
    #   assert subscription_item_1.updated_at == subscription_item_factory.updated_at

    #   assert subscription_item_2.quantity == 1
    #   assert subscription_item_2.price_id == price.id

    #   billing_period_in_seconds =
    #     DateTime.diff(subscription.current_period_end, subscription.current_period_start)

    #   debit_remaining_time =
    #     subscription.current_period_end
    #     |> DateTime.diff(proration_date)
    #     |> Kernel.*(100)
    #     |> Decimal.div(billing_period_in_seconds)
    #     |> Decimal.mult(subscription_item_2.price.unit_amount * subscription_item_2.quantity)
    #     |> Decimal.div(100)
    #     |> Decimal.round()
    #     |> Decimal.to_integer()

    #   assert %{data: [debit_invoice_item]} =
    #            InvoiceItems.list_invoice_items(filter: [subscription_id: subscription.id])

    #   assert debit_invoice_item.amount == debit_remaining_time
    #   assert debit_invoice_item.is_proration
    #   assert debit_invoice_item.subscription_item_id == subscription_item_1.id
    #   assert debit_invoice_item.period_start == proration_date
    #   assert debit_invoice_item.period_end == subscription.current_period_end
    # end

    test "when one of the item's price is not with the same interval, returns an invalid changeset" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> insert!()

      price_2 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_month()
        |> insert!()

      %{items: [subscription_item]} =
        subscription =
        insert!(:subscription,
          account_id: account.id,
          items: [build(:subscription_item, account_id: account.id, price_id: price_1.id)]
        )

      assert {:error, changeset} =
               Subscriptions.update_subscription(subscription, %{
                 items: [%{id: subscription_item.id, is_deleted: false, price_id: price_2.id}],
                 proration_behavior: Subscription.proration_behaviors().none
               })

      refute changeset.valid?

      assert %{
               items: [
                 %{
                   price_id: [
                     "price must match the recurring_interval `day` and the recurring_interval_count `1`"
                   ]
                 }
               ]
             } = errors_on(changeset)
    end

    test "when one of the item's price is not with the same interval count, returns an invalid changeset" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day(%{recurring_interval_count: 1})
        |> insert!()

      price_2 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day(%{recurring_interval_count: 2})
        |> insert!()

      %{items: [subscription_item]} =
        subscription =
        insert!(:subscription,
          account_id: account.id,
          items: [build(:subscription_item, account_id: account.id, price_id: price_1.id)]
        )

      assert {:error, changeset} =
               Subscriptions.update_subscription(subscription, %{
                 items: [%{id: subscription_item.id, is_deleted: false, price_id: price_2.id}],
                 proration_behavior: Subscription.proration_behaviors().none
               })

      refute changeset.valid?

      assert %{
               items: [
                 %{
                   price_id: [
                     "price must match the recurring_interval `day` and the recurring_interval_count `1`"
                   ]
                 }
               ]
             } = errors_on(changeset)
    end

    test "update with a price from another account, returns an invalid changeset" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> insert!()

      price_2 =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> insert!()

      %{items: [subscription_item]} =
        subscription =
        insert!(:subscription,
          account_id: account.id,
          items: [build(:subscription_item, account_id: account.id, price_id: price_1.id)]
        )

      assert {:error, changeset} =
               Subscriptions.update_subscription(subscription, %{
                 items: [%{id: subscription_item.id, is_deleted: false, price_id: price_2.id}],
                 proration_behavior: Subscription.proration_behaviors().none
               })

      refute changeset.valid?

      assert %{items: [%{price_id: ["does not exist"]}]} = errors_on(changeset)
    end

    test "update with a price with the same interval fields but with an another currency, returns an invalid changeset" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id, currency: Price.currencies().ils)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> insert!()

      price_2 =
        build(:price, account_id: account.id, currency: Price.currencies().eur)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> insert!()

      %{items: [subscription_item]} =
        subscription =
        insert!(:subscription,
          account_id: account.id,
          items: [build(:subscription_item, account_id: account.id, price_id: price_1.id)]
        )

      assert {:error, changeset} =
               Subscriptions.update_subscription(subscription, %{
                 items: [%{id: subscription_item.id, is_deleted: false, price_id: price_2.id}],
                 proration_behavior: Subscription.proration_behaviors().none
               })

      refute changeset.valid?

      assert %{
               items: [%{currency: ["price must match the currency `#{Price.currencies().ils}`"]}]
             } == errors_on(changeset)
    end

    test "update with a price with the same interval fields but with a price that already exists in a subscription_item of the subscription, returns an invalid changeset" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> insert!()

      price_2 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> insert!()

      %{items: subscription_items} =
        subscription =
        insert!(:subscription,
          account_id: account.id,
          items: [
            build(:subscription_item, account_id: account.id, price_id: price_1.id),
            build(:subscription_item, account_id: account.id, price_id: price_2.id)
          ]
        )

      subscription_item_price_1 = subscription_items |> Enum.find(&(&1.price_id == price_1.id))

      assert {:error, changeset} =
               Subscriptions.update_subscription(subscription, %{
                 items: [
                   %{id: subscription_item_price_1.id, is_deleted: false, price_id: price_2.id}
                 ],
                 proration_behavior: Subscription.proration_behaviors().none
               })

      refute changeset.valid?

      assert %{items: ["cannot add multiple subscription items with the same price"]} ==
               errors_on(changeset)
    end
  end
end
