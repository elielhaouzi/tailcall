defmodule Tailcall.Billing.Subscriptions do
  @moduledoc """
  The subscriptions context.
  """
  import Ecto.Changeset,
    only: [add_error: 3, get_field: 2, get_field: 3, prepare_changes: 2, put_change: 3]

  import Ecto.Query, only: [order_by: 2, where: 2, where: 3]

  alias Ecto.Multi

  alias Tailcall.Repo

  alias Tailcall.Accounts
  alias Tailcall.Core.Customers
  alias Tailcall.Billing.Prices.Price
  alias Tailcall.Billing.Invoices
  alias Tailcall.Billing.Subscriptions.{Subscription, SubscriptionItem, SubscriptionQueryable}
  alias Tailcall.Billing.Subscriptions.Workers.RenewSubscriptionWorker

  @default_order_by [asc: :id]
  @default_page_number 1
  @default_page_size 100

  @spec list_subscriptions(keyword) :: %{data: [Subscription.t()], total: integer}
  def list_subscriptions(opts \\ []) do
    order_by_fields = list_order_by_fields(opts)

    page_number = Keyword.get(opts, :page_number, @default_page_number)
    page_size = Keyword.get(opts, :page_size, @default_page_size)

    query = subscription_queryable(opts)

    count = query |> Repo.aggregate(:count, :id)

    subscriptions =
      query
      |> order_by(^order_by_fields)
      |> SubscriptionQueryable.paginate(page_number, page_size)
      |> Repo.all()

    %{total: count, data: subscriptions}
  end

  @spec get_subscription!(binary, keyword) :: Subscription.t() | nil
  def get_subscription!(id, opts \\ []) when is_binary(id) do
    filters = opts |> Keyword.get(:filters, []) |> Keyword.put(:id, id)

    opts
    |> Keyword.put(:filters, filters)
    |> subscription_queryable()
    |> Repo.one!()
  end

  @spec get_subscription(binary, keyword) :: Subscription.t() | nil
  def get_subscription(id, opts \\ []) when is_binary(id) do
    filters = opts |> Keyword.get(:filters, []) |> Keyword.put(:id, id)

    opts
    |> Keyword.put(:filters, filters)
    |> subscription_queryable()
    |> Repo.one()
  end

  @spec create_subscription(map()) :: {:ok, Subscription.t()} | {:error, Ecto.Changeset.t()}
  def create_subscription(attrs) when is_map(attrs) do
    utc_now = DateTime.utc_now()

    attrs = attrs |> Map.merge(%{created_at: utc_now})

    Multi.new()
    |> Multi.insert(:subscription, fn %{} ->
      %Subscription{}
      |> Subscription.create_changeset(attrs)
      |> validate_create_changes()
      |> put_periods()
    end)
    |> Multi.run(:invoice, fn _repo, %{subscription: subscription} ->
      subscription
      |> Repo.preload(items: [price: :product])
      |> build_invoice()
      |> Invoices.create_invoice()
    end)
    |> Multi.update(
      :subscription_with_status,
      fn %{
           invoice: %{status: "draft"},
           subscription: %{collection_method: "send_invoice"} = subscription
         } ->
        subscription
        |> Subscription.update_changeset(%{status: Subscription.statuses().active})
      end
    )
    |> Oban.insert(:renew_subscription_job, fn %{subscription_with_status: subscription} ->
      %{id: subscription.id}
      |> RenewSubscriptionWorker.new(scheduled_at: subscription.next_period_start)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{subscription_with_status: %Subscription{} = subscription, invoice: invoice}} ->
        {
          :ok,
          subscription |> Map.merge(%{latest_invoice_id: invoice.id, latest_invoice: invoice})
        }

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @spec renew_subscription(Subscription.t()) ::
          {:ok, Subscription.t()} | {:error, Ecto.Changeset.t()}
  def renew_subscription(%Subscription{} = subscription) do
    subscription = subscription |> Repo.preload(items: [price: :product])

    %{recurring_interval: recurring_interval, recurring_interval_count: recurring_interval_count} =
      extract_recurring_data(subscription)

    %{
      last: {last_period_start, last_period_end},
      current: {current_period_start, current_period_end},
      next: {next_period_start, next_period_end}
    } =
      calculate_next_periods(%{
        started_at: subscription.started_at,
        current_period_start: subscription.current_period_start,
        current_period_end: subscription.current_period_end,
        recurring_interval: recurring_interval,
        recurring_interval_count: recurring_interval_count
      })

    Multi.new()
    |> Multi.run(:invoice, fn _repo, %{} ->
      subscription
      |> Map.merge(%{
        last_period_start: last_period_start,
        last_period_end: last_period_end,
        current_period_start: current_period_start,
        current_period_end: current_period_end,
        next_period_start: next_period_start,
        next_period_end: next_period_end
      })
      |> build_invoice()
      |> Invoices.create_invoice()
    end)
    |> Multi.update(
      :subscription,
      fn %{invoice: %{status: "draft"}} ->
        subscription
        |> Ecto.Changeset.change()
        |> put_periods()
      end
    )
    |> Oban.insert(:renew_subscription_job, fn %{subscription: subscription} ->
      %{id: subscription.id}
      |> RenewSubscriptionWorker.new(scheduled_at: subscription.next_period_start)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{subscription: %Subscription{} = subscription, invoice: invoice}} ->
        {
          :ok,
          subscription |> Map.merge(%{latest_invoice_id: invoice.id, latest_invoice: invoice})
        }

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @spec cancel_subscription(Subscription.t(), map) ::
          {:ok, Subscription.t()} | {:error, Ecto.Changeset.t()}
  def cancel_subscription(%Subscription{} = subscription, attrs) do
    cancel_at_period_end = Map.get(attrs, :cancel_at_period_end)

    attrs =
      if cancel_at_period_end do
        attrs
        |> Map.merge(%{
          cancel_at: subscription.current_period_end,
          canceled_at: DateTime.utc_now()
        })
      else
        attrs
      end

    Multi.new()
    |> Multi.update(:subscription, Subscription.cancel_changeset(subscription, attrs))
    |> Multi.run(:cancel_job, fn repo, %{subscription: subscription} ->
      worker = Oban.Worker.to_string(RenewSubscriptionWorker)
      args = %{"id" => subscription.id}

      Oban.Job
      |> where(worker: ^worker, queue: "subscriptions")
      |> where([_job], fragment("args @> ?", ^args))
      |> repo.one()
      |> case do
        %Oban.Job{id: id} -> {:ok, Oban.cancel_job(id)}
        nil -> {:ok, nil}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{subscription: %Subscription{} = subscription}} -> {:ok, subscription}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  defp validate_create_changes(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_create_changes(changeset) do
    changeset
    |> validate_subscription_items_constaints()
    |> prepare_changes(fn changeset ->
      changeset
      |> assoc_constraint_account()
      |> assoc_constraint_customer()
    end)
  end

  defp assoc_constraint_account(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp assoc_constraint_account(%Ecto.Changeset{valid?: true} = changeset) do
    account_id = Ecto.Changeset.get_field(changeset, :account_id)

    if Accounts.account_exists?(account_id) do
      changeset
    else
      changeset |> Ecto.Changeset.add_error(:account, "does not exist")
    end
  end

  defp assoc_constraint_customer(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp assoc_constraint_customer(%Ecto.Changeset{valid?: true} = changeset) do
    customer_id = Ecto.Changeset.get_field(changeset, :customer_id)
    account_id = Ecto.Changeset.get_field(changeset, :account_id)

    if Customers.customer_exists?(customer_id, filters: [account_id: account_id]) do
      changeset
    else
      changeset |> Ecto.Changeset.add_error(:customer, "does not exist")
    end
  end

  defp validate_subscription_items_constaints(%Ecto.Changeset{} = changeset) do
    subscription_items = changeset |> get_field(:items, []) |> Enum.map(&Repo.preload(&1, :price))

    changeset
    |> validate_belongs_to_same_account(subscription_items)
    |> validate_belongs_to_the_subscription_account(subscription_items)
    |> validate_same_recurring_interval_fields(subscription_items)
    |> validate_same_currency(subscription_items)
  end

  # defp validate_belongs_to_same_account(%Ecto.Changeset{valid?: false} = changeset, _),
  #   do: changeset

  defp validate_belongs_to_same_account(%Ecto.Changeset{} = changeset, subscription_items)
       when is_list(subscription_items) do
    uniq_prices_account_id =
      subscription_items
      |> Enum.map(& &1.price.account_id)
      |> Enum.uniq()

    if length(uniq_prices_account_id) == 1 do
      changeset
    else
      changeset
      |> add_error(:items, "account must match across all prices")
    end
  end

  defp validate_belongs_to_the_subscription_account(
         %Ecto.Changeset{valid?: false} = changeset,
         _
       ),
       do: changeset

  defp validate_belongs_to_the_subscription_account(
         %Ecto.Changeset{} = changeset,
         subscription_items
       )
       when is_list(subscription_items) do
    subscription_account_id = get_field(changeset, :account_id)

    [uniq_prices_account_id] =
      subscription_items
      |> Enum.map(& &1.price.account_id)
      |> Enum.uniq()

    if uniq_prices_account_id == subscription_account_id do
      changeset
    else
      changeset
      |> add_error(:items, "prices must belongs to account #{subscription_account_id}")
    end
  end

  defp validate_same_recurring_interval_fields(%Ecto.Changeset{valid?: false} = changeset, _),
    do: changeset

  defp validate_same_recurring_interval_fields(%Ecto.Changeset{} = changeset, subscription_items)
       when is_list(subscription_items) do
    uniq_intervals =
      subscription_items
      |> Enum.map(& &1.price.recurring_interval)
      |> Enum.uniq()

    uniq_interval_counts =
      subscription_items
      |> Enum.map(& &1.price.recurring_interval_count)
      |> Enum.uniq()

    if length(uniq_intervals) == 1 and length(uniq_interval_counts) == 1 do
      changeset
    else
      changeset
      |> add_error(:items, "interval fields must match across all prices")
    end
  end

  defp validate_same_currency(%Ecto.Changeset{valid?: false} = changeset, _), do: changeset

  defp validate_same_currency(%Ecto.Changeset{} = changeset, subscription_items)
       when is_list(subscription_items) do
    uniq_currencies =
      subscription_items
      |> Enum.map(& &1.price.currency)
      |> Enum.uniq()

    if length(uniq_currencies) == 1 do
      changeset
    else
      changeset
      |> add_error(:items, "currency must match across all prices")
    end
  end

  defp put_periods(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp put_periods(%Ecto.Changeset{} = changeset) do
    started_at = get_field(changeset, :started_at)
    current_period_start = get_field(changeset, :current_period_start)
    current_period_end = get_field(changeset, :current_period_end)

    %{recurring_interval: recurring_interval, recurring_interval_count: recurring_interval_count} =
      changeset
      |> get_field(:items)
      |> List.first()
      |> Repo.preload(:price)
      |> Map.get(:price)

    %{
      last: {last_period_end, last_period_start},
      current: {current_period_start, current_period_end},
      next: {next_period_start, next_period_end}
    } =
      calculate_next_periods(%{
        started_at: started_at,
        current_period_start: current_period_start,
        current_period_end: current_period_end,
        recurring_interval: recurring_interval,
        recurring_interval_count: recurring_interval_count
      })

    changeset
    |> put_change(:current_period_start, current_period_start)
    |> put_change(:current_period_end, current_period_end)
    |> put_change(:last_period_start, last_period_start)
    |> put_change(:last_period_end, last_period_end)
    |> put_change(:next_period_start, next_period_start)
    |> put_change(:next_period_end, next_period_end)
  end

  defp extract_recurring_data(%Subscription{items: [%{price: price} | _]}) do
    %{
      recurring_interval: price.recurring_interval,
      recurring_interval_count: price.recurring_interval_count
    }
  end

  defp calculate_next_periods(%{
         started_at: %DateTime{} = started_at,
         current_period_start: current_period_start,
         current_period_end: current_period_end,
         recurring_interval: recurring_interval,
         recurring_interval_count: recurring_interval_count
       }) do
    last_period_start = current_period_start || started_at
    last_period_end = current_period_end || started_at

    current_period_start = last_period_end
    current_period_end = shift(current_period_start, recurring_interval, recurring_interval_count)

    next_period_start = current_period_end
    next_period_end = shift(next_period_start, recurring_interval, recurring_interval_count)

    %{
      last: {last_period_start, last_period_end},
      current: {current_period_start, current_period_end},
      next: {next_period_start, next_period_end}
    }
  end

  defp shift(%DateTime{} = from, interval, interval_count)
       when interval in ["day", "month"] and is_integer(interval_count) do
    Timex.shift(from, [{String.to_atom("#{interval}s"), interval_count}])
  end

  defp build_invoice(%Subscription{items: subscription_items, status: status} = subscription) do
    billing_reason =
      if is_nil(status),
        do: Invoices.Invoice.billing_reasons().subscription_create,
        else: Invoices.Invoice.billing_reasons().subscription_cycle

    %{
      account_id: subscription.account_id,
      customer_id: subscription.customer_id,
      subscription_id: subscription.id,
      billing_reason: billing_reason,
      currency: currency(subscription),
      line_items: subscription_items |> Enum.map(&build_invoice_line_item(subscription, &1)),
      livemode: subscription.livemode,
      period_start: subscription.last_period_start,
      period_end: subscription.last_period_end,
      total: calculate_total(subscription)
    }
  end

  defp build_invoice_line_item(
         %Subscription{} = subscription,
         %SubscriptionItem{} = subscription_item
       ) do
    %{
      amount: calculate_amount(subscription_item),
      period_end: subscription.current_period_end,
      period_start: subscription.current_period_start,
      price_id: subscription_item.price_id,
      quantity: subscription_item.quantity,
      subscription_item_id: subscription_item.id,
      type: Invoices.InvoiceLineItem.types().subscription
    }
  end

  defp currency(%Subscription{items: [subscription_item | _]}) do
    %{price: %{currency: currency}} = subscription_item |> Repo.preload(:price)

    currency
  end

  defp calculate_total(%Subscription{items: subscription_items}) do
    subscription_items
    |> Enum.reduce(0, fn subscription_item, acc ->
      acc + calculate_amount(subscription_item)
    end)
  end

  defp calculate_amount(%SubscriptionItem{price: %Price{} = price, quantity: quantity}) do
    price.unit_amount * quantity
  end

  @spec subscription_queryable(keyword) :: Ecto.Queryable.t()
  def subscription_queryable(opts \\ []) when is_list(opts) do
    filters = Keyword.get(opts, :filters, [])
    includes = Keyword.get(opts, :includes, []) |> Enum.concat([:items]) |> Enum.uniq()

    SubscriptionQueryable.queryable()
    |> SubscriptionQueryable.filter(filters)
    |> SubscriptionQueryable.with_preloads(includes)
  end

  defp list_order_by_fields(opts) do
    Keyword.get(opts, :order_by_fields, [])
    |> case do
      [] -> @default_order_by
      [_ | _] = order_by_fields -> order_by_fields
    end
  end
end
