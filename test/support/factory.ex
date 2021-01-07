defmodule Tailcall.Factory do
  alias Tailcall.Repo

  use Tailcall.Factory.Accounts.User
  use Tailcall.Factory.Accounts.ApiKey

  use Tailcall.Factory.Audit.Event

  # use Tailcall.Factory.Customer

  # use Tailcall.Factory.TaxRate
  # use Tailcall.Factory.CustomerTaxId

  # use Tailcall.Factory.Coupon
  # use Tailcall.Factory.Discount

  # use Tailcall.Factory.Product
  # use Tailcall.Factory.Price
  # use Tailcall.Factory.Subscription

  # use Tailcall.Factory.Invoice

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
