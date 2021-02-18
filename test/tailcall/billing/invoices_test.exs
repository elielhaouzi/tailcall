defmodule Tailcall.Billing.InvoincesTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Billing.Prices.Price

  alias Tailcall.Billing.Invoices
  alias Tailcall.Billing.Invoices.Invoice
  alias Tailcall.Billing.Invoices.Workers.AutomaticCollectionWorker

  @moduletag :invoices

  describe "list_invoices/1" do
    test "list invoices" do
      %{id: invoice_id} = insert!(:invoice)

      assert %{total: 1, data: [%{id: ^invoice_id}]} = Invoices.list_invoices()
    end

    test "order_by" do
      %{id: id1} = insert!(:invoice)
      %{id: id2} = insert!(:invoice)

      assert %{data: [%{id: ^id1}, %{id: ^id2}]} = Invoices.list_invoices()

      assert %{data: [%{id: ^id2}, %{id: ^id1}]} =
               Invoices.list_invoices(order_by_fields: [desc: :id])
    end

    test "filters" do
      invoice = insert!(:invoice)

      [
        [id: invoice.id],
        [id: [invoice.id]],
        [account_id: invoice.account_id],
        [customer_id: invoice.customer_id],
        [subscription_id: invoice.subscription_id],
        [livemode: invoice.livemode],
        [status: invoice.status]
      ]
      |> Enum.each(fn filter ->
        assert %{total: 1, data: [_price]} = Invoices.list_invoices(filters: filter)
      end)

      [
        [id: shortcode_id()],
        [account_id: shortcode_id()],
        [customer_id: shortcode_id()],
        [subscription_id: shortcode_id()],
        [livemode: !invoice.livemode],
        [status: "status"]
      ]
      |> Enum.each(fn filter ->
        assert %{total: 0, data: []} = Invoices.list_invoices(filters: filter)
      end)
    end

    test "includes" do
      insert!(:invoice)

      %{data: [invoice], total: 1} = Invoices.list_invoices()

      assert Ecto.assoc_loaded?(invoice.line_items)
      assert Map.has_key?(invoice, :subscription_id)
      refute Ecto.assoc_loaded?(invoice.subscription)

      %{data: [invoice], total: 1} = Invoices.list_invoices(includes: [:subscription])

      assert Ecto.assoc_loaded?(invoice.subscription)
      assert Ecto.assoc_loaded?(invoice.subscription.items)
    end
  end

  describe "get_invoice/2" do
    test "returns the invoice" do
      %{id: id} = insert!(:invoice)
      assert %{id: ^id} = Invoices.get_invoice(id)
    end

    test "when the invoice does not exist, returns nil" do
      assert is_nil(Invoices.get_invoice(shortcode_id()))
    end

    test "includes" do
      invoice_factory = insert!(:invoice)

      invoice = Invoices.get_invoice(invoice_factory.id)
      assert Ecto.assoc_loaded?(invoice.line_items)
      refute Ecto.assoc_loaded?(invoice.subscription)

      invoice = Invoices.get_invoice(invoice_factory.id, includes: [:subscription])

      assert Ecto.assoc_loaded?(invoice.line_items)
      assert Ecto.assoc_loaded?(invoice.subscription)
    end
  end

  describe "get_invoice!/2" do
    test "returns the invoice" do
      %{id: id} = insert!(:invoice)
      assert %{id: ^id} = Invoices.get_invoice!(id)
    end

    test "when the invoice does not exist, raises a Ecto.NoResultsError" do
      assert_raise Ecto.NoResultsError, fn ->
        Invoices.get_invoice!(shortcode_id())
      end
    end
  end

  describe "create_invoices/1" do
    test "when params are valid, creates a invoice" do
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

      %{items: [subscription_item]} =
        subscription =
        insert!(:subscription,
          account_id: account.id,
          customer_id: customer.id,
          items: [build(:subscription_item, price_id: price.id, quantity: 2)]
        )

      assert {:ok, %Invoice{line_items: [invoice_line_item]} = invoice} =
               Invoices.create_invoice(%{
                 account_id: subscription.account_id,
                 customer_id: subscription.customer_id,
                 subscription_id: subscription.id,
                 account_name: account.name,
                 billing_reason: Invoice.billing_reasons().subscription_create,
                 currency: price.currency,
                 customer_email: customer.email,
                 customer_name: customer.name,
                 line_items: [
                   %{
                     amount: price.unit_amount * subscription_item.quantity,
                     period_end: subscription.current_period_end,
                     period_start: subscription.current_period_start,
                     price_id: subscription_item.price_id,
                     quantity: subscription_item.quantity,
                     subscription_item_id: subscription_item.id,
                     type: Invoices.InvoiceLineItem.types().subscription
                   }
                 ],
                 livemode: subscription.livemode,
                 period_end: subscription.current_period_start,
                 period_start: subscription.current_period_start,
                 total: price.unit_amount * subscription_item.quantity
               })

      assert invoice.account_id == subscription.account_id
      assert invoice.account_name == account.name
      assert invoice.amount_due == price.unit_amount * subscription_item.quantity
      assert invoice.amount_paid == 0
      assert invoice.amount_remaining == invoice.amount_due - invoice.amount_paid
      assert invoice.billing_reason == Invoice.billing_reasons().subscription_create

      assert invoice.customer_id == customer.id
      assert invoice.customer_email == customer.email
      assert invoice.customer_name == customer.name
      assert invoice.currency == price.currency
      assert invoice.period_end == subscription.current_period_start
      assert invoice.period_start == subscription.current_period_start
      assert invoice.subscription_id == subscription.id
      assert invoice.status == Invoice.statuses().draft
      assert invoice.total == price.unit_amount * subscription_item.quantity

      assert invoice_line_item.amount == price.unit_amount * subscription_item.quantity
      assert invoice_line_item.currency == price.currency
      assert invoice_line_item.period_end == subscription.current_period_start
      assert invoice_line_item.period_start == subscription.current_period_start
      assert invoice_line_item.quantity == subscription_item.quantity
      assert invoice_line_item.type == Invoices.InvoiceLineItem.types().subscription
    end

    test "when numbering_scheme is by account_level, invoice_prefix is according to the account level" do
      %{invoice_settings: %{invoice_prefix: invoice_prefix}} = account = insert!(:account)

      invoice_params = params_for(:invoice, account_id: account.id)

      assert {:ok, %Invoice{} = invoice} = Invoices.create_invoice(invoice_params)

      assert invoice.number == invoice_prefix <> "-DRAFT"
    end

    # test "when numbering_scheme is by customer_level, invoice_prefix is according to the customer level" do
    #   account =
    #     insert!(:account,
    #       invoice_settings: %{
    #         numbering_scheme: Tailcall.Accounts.InvoiceSettings.numbering_scheme().customer_level
    #       }
    #     )

    #   %{invoice_prefix: invoice_prefix} = customer = insert!(:customer)

    #   invoice_params = params_for(:invoice, account_id: account.id, customer_id: customer.id)

    #   assert {:ok, %Invoice{} = invoice} = Invoices.create_invoice(invoice_params)

    #   assert invoice.number == invoice_prefix <> "-DRAFT"
    # end

    test "when collection_method is `send_invoice`, due_date can be set" do
      account =
        insert!(:account,
          invoice_settings:
            build(:account_invoice_settings, numbering_scheme: "account_level", days_until_due: 1)
        )

      invoice_params =
        params_for(:invoice,
          account_id: account.id,
          collection_method: Invoice.collection_methods().send_invoice,
          days_until_due: 2
        )

      assert {:ok, %Invoice{} = invoice} = Invoices.create_invoice(invoice_params)

      assert invoice.due_date ==
               add(invoice.created_at, invoice_params.days_until_due * 24 * 3600)
    end

    test "when collection_method is `send_invoice` and neither days_until_due nor due_date is set, set due_date according to days_until_due account" do
      account =
        insert!(:account,
          invoice_settings: build(:account_invoice_settings, numbering_scheme: "account_level")
        )

      invoice_params =
        params_for(:invoice,
          collection_method: Invoice.collection_methods().send_invoice,
          account_id: account.id
        )

      assert {:ok, %Invoice{} = invoice} = Invoices.create_invoice(invoice_params)

      invoice_due_date =
        invoice.created_at |> add(account.invoice_settings.days_until_due * 24 * 3600)

      assert invoice.due_date == invoice_due_date
    end

    test "when the create_invoice failed, does not enqueue a job" do
      assert {:error, _changeset} = Invoices.create_invoice(%{})
      refute_enqueued(worker: AutomaticCollectionWorker)
    end

    test "when creating an auto_advance invoice, enqueue a job" do
      invoice_params = params_for(:invoice, auto_advance: true)
      assert {:ok, invoice} = Invoices.create_invoice(invoice_params)

      assert_enqueued(
        worker: AutomaticCollectionWorker,
        args: %{id: invoice.id},
        scheduled_at: DateTime.add(invoice.created_at, 3600, :second)
      )
    end

    test "when creating an invoice without auto_advance, does not enqueue a job" do
      invoice_params = params_for(:invoice, auto_advance: false)
      assert {:ok, _invoice} = Invoices.create_invoice(invoice_params)
      refute_enqueued(worker: AutomaticCollectionWorker)
    end

    test "when account does not exist, returns an error tuple with an invalid changeset" do
      account_id = shortcode_id("acct")

      invoice_params = params_for(:invoice, account_id: account_id)

      assert {:error, changeset} = Invoices.create_invoice(invoice_params)

      refute changeset.valid?
      assert %{account: ["does not exist"]} = errors_on(changeset)
    end

    test "when customer does not exist, returns an error tuple with an invalid changeset" do
      customer_id = shortcode_id("cus")

      invoice_params = params_for(:invoice, customer_id: customer_id)

      assert {:error, changeset} = Invoices.create_invoice(invoice_params)

      refute changeset.valid?
      assert %{customer: ["does not exist"]} = errors_on(changeset)
    end

    test "when customer does not belong to the account, returns an invalid changeset" do
      account = insert!(:account)
      customer = insert!(:customer)

      invoice_params = params_for(:invoice, account_id: account.id, customer_id: customer.id)

      assert {:error, changeset} = Invoices.create_invoice(invoice_params)

      refute changeset.valid?
      assert %{customer: ["does not exist"]} = errors_on(changeset)
    end

    test "when the subscription does not exist, returns an error tuple with an invalid changeset" do
      subscription_id = shortcode_id("sub")

      invoice_params = params_for(:invoice) |> Map.put(:subscription_id, subscription_id)

      assert {:error, changeset} = Invoices.create_invoice(invoice_params)

      refute changeset.valid?
      assert %{subscription: ["does not exist"]} = errors_on(changeset)
    end

    test "when subscription does not belong to the account, returns an invalid changeset" do
      account = insert!(:account)
      subscription = insert!(:subscription)

      invoice_params =
        params_for(:invoice, account_id: account.id, subscription_id: subscription.id)

      assert {:error, changeset} = Invoices.create_invoice(invoice_params)

      refute changeset.valid?
      assert %{subscription: ["does not exist"]} = errors_on(changeset)
    end
  end

  describe "finalize_invoice/1" do
    test "when status is draft, advances the invoice to open" do
      account = insert!(:account)
      insert!(:sequence, name: account.id)

      invoice =
        insert!(:invoice, account_id: account.id, status: Invoice.statuses().draft)
        |> Map.put(:account, account)

      open_status = Invoice.statuses().open

      assert {:ok, %Invoice{status: ^open_status}} = Invoices.finalize_invoice(invoice)
    end

    test "when numbering_scheme is by account_level, invoice number is according to the account level" do
      %{invoice_settings: %{invoice_prefix: invoice_prefix}} = account = insert!(:account)

      customer = insert!(:customer, next_invoice_sequence: 1)

      %{value: sequence_value} =
        insert!(:sequence, name: account.id, livemode: customer.livemode, value: 5)

      invoice =
        insert!(:invoice,
          account: account,
          account_id: account.id,
          customer_id: customer.id,
          status: Invoice.statuses().draft,
          number: "#{invoice_prefix}-DRAFT"
        )

      assert {:ok, %Invoice{} = invoice} = Invoices.finalize_invoice(invoice)

      invoice_number = (sequence_value + 1) |> Integer.to_string() |> String.pad_leading(5, "0")

      assert invoice.number == "#{invoice_prefix}-#{invoice_number}"
    end

    # test "when numbering_scheme is by customer_level, invoice number is according to the customer level" do
    #   %{
    #     invoice_settings: %{
    #       invoice_prefix: invoice_prefix,
    #       next_invoice_sequence_testmode: next_invoice_sequence_testmode
    #     }
    #   } = account = insert!(:account, invoice_settings: %{next_invoice_sequence_testmode: 5})

    #   customer = insert!(:customer, next_invoice_sequence: 1)

    #   invoice =
    #     insert!(:invoice,
    #       account_id: account.id,
    #       customer_id: customer.id,
    #       status: Invoice.statuses().draft
    #     )

    #   assert {:ok, %Invoice{} = invoice} = Invoices.finalize_invoice(invoice)

    #   invoice_number =
    #     (next_invoice_sequence_testmode + 1) |> Integer.to_string() |> String.pad_leading(5, "0")

    #   assert invoice.number == "#{invoice_prefix}-#{invoice_number}"
    # end

    test "AutomaticCollectionWorker worker when status is draft, finalize the invoice" do
      account = insert!(:account)
      insert!(:sequence, name: account.id, value: 5)

      invoice = insert!(:invoice, account_id: account.id, status: Invoice.statuses().draft)
      open_status = Invoice.statuses().open

      assert {:ok, _} = perform_job(AutomaticCollectionWorker, %{"id" => invoice.id})

      assert %Invoice{status: ^open_status} = Invoices.get_invoice!(invoice.id)
    end

    test "when status is not draft, returns an error tuple" do
      invoice = insert!(:invoice, status: Invoice.statuses().open)
      assert {:error, :invalid_action} = Invoices.finalize_invoice(invoice)
    end

    test "AutomaticCollectionWorker worker when status is not draft, collects the invoice" do
      open_status = Invoice.statuses().open
      invoice = insert!(:invoice, status: open_status)

      assert {:ok, _} = perform_job(AutomaticCollectionWorker, %{"id" => invoice.id})

      assert %Invoice{status: ^open_status} = Invoices.get_invoice!(invoice.id)
    end
  end
end
