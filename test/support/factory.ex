defmodule Billing.Factory do
  alias Billing.Repo

  use Billing.Factory.Accounts.User
  use Billing.Factory.Accounts.ApiKey

  use Billing.Factory.Audit.Event

  # use Billing.Factory.Customer

  # use Billing.Factory.TaxRate
  # use Billing.Factory.CustomerTaxId

  # use Billing.Factory.Coupon
  # use Billing.Factory.Discount

  # use Billing.Factory.Product
  # use Billing.Factory.Price
  # use Billing.Factory.Subscription

  # use Billing.Factory.Invoice

  @spec uuid :: <<_::288>>
  def uuid(), do: Ecto.UUID.generate()

  @spec shortcode_uuid(nil | binary) :: binary
  def shortcode_uuid(prefix \\ nil), do: uuid() |> Shortcode.to_shortcode!(prefix)

  @spec id :: integer
  def id(), do: System.unique_integer([:positive])

  @spec shortcode_id(nil | binary) :: binary
  def shortcode_id(prefix \\ nil), do: id() |> Shortcode.to_shortcode!(prefix)

  @spec utc_now :: DateTime.t()
  def utc_now(), do: DateTime.utc_now() |> DateTime.truncate(:second)

  @spec add(DateTime.t(), integer, System.time_unit()) :: DateTime.t()
  def add(%DateTime{} = datetime, amount_of_time, time_unit \\ :second) do
    datetime |> DateTime.add(amount_of_time, time_unit)
  end

  @spec params_for(map) :: map
  def params_for(schema) when is_struct(schema) do
    schema
    |> AntlUtilsEcto.map_from_struct()
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  @spec params_for(atom, Enum.t()) :: map
  def params_for(factory_name, attributes \\ []) do
    factory_name |> build(attributes) |> params_for()
  end

  @spec build(atom, Enum.t()) :: %{:__struct__ => atom, optional(atom) => any}
  def build(factory_name, attributes) do
    factory_name |> build() |> struct!(attributes)
  end

  @spec insert!(atom, Enum.t()) :: any
  def insert!(factory_name, attributes \\ []) do
    factory_name |> build(attributes) |> Repo.insert!()
  end
end
