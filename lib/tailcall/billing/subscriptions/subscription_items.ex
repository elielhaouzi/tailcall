defmodule Tailcall.Billing.Subscriptions.SubscriptionItems do
  import TailcallWeb.Gettext, only: [gettext: 2]

  alias Ecto.Multi
  alias Tailcall.Repo

  alias Tailcall.Core.Customers.Customer
  alias Tailcall.Billing.Products.Product
  alias Tailcall.Billing.Prices.Price
  alias Tailcall.Billing.InvoiceItems
  alias Tailcall.Billing.Subscriptions
  alias Tailcall.Billing.Subscriptions.Subscription
  alias Tailcall.Billing.Subscriptions.SubscriptionItems.SubscriptionItem

  @spec create_subscription_item(Subscription.t(), map, keyword) ::
          {:ok, SubscriptionItem.t()} | {:error, Ecto.Changeset.t()}
  def create_subscription_item(%Subscription{} = subscription, attrs, opts \\ [])
      when is_map(attrs) do
    utc_now = DateTime.utc_now()

    proration_behavior = Map.get(attrs, :proration_behavior)
    proration_date = Map.get(attrs, :proration_date, utc_now)

    Multi.new()
    |> Multi.run(:lock_subscription?, fn _, %{} ->
      {:ok, Keyword.get(opts, :lock_subscription?, true)}
    end)
    |> Multi.run(:reload_subscription?, fn _, %{} ->
      {:ok, Keyword.get(opts, :reload_subscription?, true)}
    end)
    |> Multi.run(:subscription, fn
      _, %{reload_subscription?: false} ->
        {:ok, subscription}

      _, %{reload_subscription?: true, lock_subscription?: lock_subscription?} ->
        {:ok,
         Subscriptions.get_subscription!(subscription.id,
           includes: [:customer, [items: [price: :product]]],
           lock?: lock_subscription?
         )}
    end)
    |> Multi.insert(:subscription_item, fn %{subscription: subscription} ->
      %SubscriptionItem{subscription: subscription, proration_date: proration_date}
      |> SubscriptionItem.create_changeset(attrs)
    end)
    |> Multi.run(:proration_behavior, fn _, %{} ->
      {:ok, proration_behavior: proration_behavior}
    end)
    |> Multi.run(:prorate_changes, fn
      _, %{proration_behavior: "none"} ->
        {:ok, nil}

      _,
      %{subscription: subscription, subscription_item: %{is_prepaid: true} = subscription_item} ->
        %{subscription_item | subscription: subscription}
        |> build_proration_debit(proration_date)
        |> List.wrap()
        |> InvoiceItems.create_invoice_items()

      _,
      %{subscription: subscription, subscription_item: %{is_prepaid: false} = subscription_item} ->
        %{subscription_item | subscription: subscription}
        |> build_proration_credit(proration_date)
        |> List.wrap()
        |> InvoiceItems.create_invoice_items()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{subscription_item: subscription_item}} -> {:ok, subscription_item}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  @spec update_subscription_item(Subscription.t(), SubscriptionItem.t(), map, keyword) ::
          {:ok, SubscriptionItem.t()} | {:error, Ecto.Changeset.t()}
  def update_subscription_item(
        %Subscription{} = subscription,
        %SubscriptionItem{} = subscription_item,
        attrs,
        opts \\ []
      )
      when is_map(attrs) do
    proration_behavior = Map.get(attrs, :proration_behavior)
    proration_date = Map.get(attrs, :proration_date, DateTime.utc_now())

    Multi.new()
    |> Multi.run(:lock_subscription?, fn _, %{} ->
      {:ok, Keyword.get(opts, :lock_subscription?, true)}
    end)
    |> Multi.run(:reload_subscription?, fn _, %{} ->
      {:ok, Keyword.get(opts, :reload_subscription?, true)}
    end)
    |> Multi.run(:subscription, fn
      _, %{reload_subscription?: false} ->
        {:ok, subscription}

      _, %{reload_subscription?: true, lock_subscription?: lock_subscription?} ->
        {:ok,
         Subscriptions.get_subscription!(subscription.id,
           includes: [:customer, [items: [price: :product]]],
           lock?: lock_subscription?
         )}
    end)
    |> Multi.update(:subscription_item, fn %{subscription: subscription} ->
      subscription_item
      |> Map.merge(%{subscription: subscription, proration_date: proration_date})
      |> SubscriptionItem.update_changeset(attrs)
    end)
    |> Multi.run(:proration_behavior, fn _, %{} ->
      {:ok, proration_behavior: proration_behavior}
    end)
    |> Multi.run(:prorate_changes, fn
      _, %{proration_behavior: "none"} ->
        {:ok, nil}

      _,
      %{
        subscription: subscription,
        subscription_item: %{is_prepaid: true} = updated_subscription_item
      } ->
        [
          build_proration_credit(
            %{subscription_item | subscription: subscription},
            proration_date
          ),
          build_proration_debit(
            %{updated_subscription_item | subscription: subscription},
            proration_date
          )
        ]
        |> InvoiceItems.create_invoice_items()

      _,
      %{
        subscription: subscription,
        subscription_item: %{is_prepaid: false} = updated_subscription_item
      } ->
        [
          build_proration_credit(
            %{updated_subscription_item | subscription: subscription},
            proration_date
          ),
          build_proration_debit(%{subscription_item | subscription: subscription}, proration_date)
        ]
        |> InvoiceItems.create_invoice_items()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{subscription_item: subscription_item}} -> {:ok, subscription_item}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  @spec delete_subscription_item(Subscription.t(), SubscriptionItem.t(), map, keyword) ::
          {:ok, SubscriptionItem.t()} | {:error, Ecto.Changeset.t()}
  def delete_subscription_item(
        %Subscription{} = subscription,
        %SubscriptionItem{} = subscription_item,
        attrs,
        opts \\ []
      )
      when is_map(attrs) do
    utc_now = DateTime.utc_now()

    proration_behavior = Map.get(attrs, :proration_behavior)
    proration_date = Map.get(attrs, :proration_date, utc_now)
    delete_at = Map.get(attrs, :delete_at, utc_now)

    Multi.new()
    |> Multi.run(:lock_subscription?, fn _, %{} ->
      {:ok, Keyword.get(opts, :lock_subscription?, true)}
    end)
    |> Multi.run(:reload_subscription?, fn _, %{} ->
      {:ok, Keyword.get(opts, :reload_subscription?, true)}
    end)
    |> Multi.run(:subscription, fn
      _, %{reload_subscription?: false} ->
        {:ok, subscription}

      _, %{reload_subscription?: true, lock_subscription?: lock_subscription?} ->
        {:ok,
         Subscriptions.get_subscription!(subscription.id,
           includes: [:customer, [items: [price: :product]]],
           lock?: lock_subscription?
         )}
    end)
    |> Multi.update(:subscription_item, fn %{subscription: subscription} ->
      subscription_item
      |> Map.merge(%{subscription: subscription, proration_date: proration_date})
      |> SubscriptionItem.update_changeset(%{deleted_at: delete_at})
    end)
    |> Multi.run(:proration_behavior, fn _, %{} ->
      {:ok, proration_behavior: proration_behavior}
    end)
    |> Multi.run(:prorate_changes, fn
      _, %{proration_behavior: "none"} ->
        {:ok, nil}

      _,
      %{subscription: subscription, subscription_item: %{is_prepaid: true} = subscription_item} ->
        %{subscription_item | subscription: subscription}
        |> build_proration_credit(proration_date)
        |> List.wrap()
        |> InvoiceItems.create_invoice_items()

      _,
      %{subscription: subscription, subscription_item: %{is_prepaid: false} = subscription_item} ->
        %{subscription_item | subscription: subscription}
        |> build_proration_debit(proration_date)
        |> List.wrap()
        |> InvoiceItems.create_invoice_items()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{subscription_item: subscription_item}} -> {:ok, subscription_item}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  defp build_proration_credit(
         %SubscriptionItem{
           is_prepaid: is_prepaid,
           price: %Price{product: %Product{} = product} = price,
           quantity: quantity,
           subscription: %Subscription{customer: %Customer{} = customer} = subscription
         } = subscription_item,
         %DateTime{} = proration_date
       ) do
    billing_period_in_seconds =
      DateTime.diff(subscription.current_period_end, subscription.current_period_start)

    {proration_period_start, proration_period_end} =
      if is_prepaid,
        do: {proration_date, subscription.current_period_end},
        else: {subscription.current_period_start, proration_date}

    amount =
      calculate_proration_amount(
        proration_period_start,
        proration_period_end,
        billing_period_in_seconds,
        price.unit_amount * quantity
      )

    description =
      gettext("Unused time on %{quantity} x %{product_name} after %{date}",
        quantity: quantity,
        product_name: product.name,
        date: DateTime.to_date(proration_date)
      )

    InvoiceItems.build_invoice_item!(customer, price, subscription, subscription_item, %{
      amount: -amount,
      description: description,
      is_proration: true,
      period_start: proration_period_start,
      period_end: proration_period_end,
      quantity: quantity
    })
  end

  defp build_proration_debit(
         %SubscriptionItem{
           is_prepaid: is_prepaid,
           price: %Price{product: %Product{} = product} = price,
           quantity: quantity,
           subscription: %Subscription{customer: %Customer{} = customer} = subscription
         } = subscription_item,
         %DateTime{} = proration_date
       ) do
    billing_period_in_seconds =
      DateTime.diff(subscription.current_period_end, subscription.current_period_start)

    {proration_period_start, proration_period_end} =
      if is_prepaid,
        do: {proration_date, subscription.current_period_end},
        else: {subscription.current_period_start, proration_date}

    amount =
      calculate_proration_amount(
        proration_period_start,
        proration_period_end,
        billing_period_in_seconds,
        price.unit_amount * quantity
      )

    description =
      gettext("Remaining time on %{quantity} x %{product_name} after %{date}",
        quantity: quantity,
        product_name: product.name,
        date: DateTime.to_date(proration_date)
      )

    InvoiceItems.build_invoice_item!(customer, price, subscription, subscription_item, %{
      amount: amount,
      description: description,
      is_proration: true,
      period_start: proration_period_start,
      period_end: proration_period_end,
      quantity: quantity
    })
  end

  defp calculate_proration_amount(
         %DateTime{} = period_start,
         %DateTime{} = period_end,
         billing_period_in_seconds,
         full_amount
       )
       when is_integer(billing_period_in_seconds) do
    period_end
    |> DateTime.diff(period_start)
    |> abs()
    |> Kernel.*(100)
    |> Decimal.div(billing_period_in_seconds)
    |> Decimal.mult(full_amount)
    |> Decimal.div(100)
    |> Decimal.round()
    |> Decimal.to_integer()
  end
end
