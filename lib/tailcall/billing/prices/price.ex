defmodule Tailcall.Billing.Prices.Price do
  use Ecto.Schema

  import Ecto.Changeset,
    only: [
      add_error: 3,
      assoc_constraint: 2,
      cast: 3,
      cast_assoc: 3,
      get_field: 2,
      get_field: 3,
      put_change: 3,
      validate_change: 3,
      validate_inclusion: 3,
      validate_inclusion: 4,
      validate_number: 3,
      validate_required: 2
    ]

  alias Tailcall.Extensions.Ecto.Changeset, as: TailcallExtensionsEctoChangeset

  alias Tailcall.Accounts.Users.User

  alias Tailcall.Billing.Products.Product
  alias Tailcall.Billing.Prices.PriceTier

  @one_is_the_default_recurring_interval_count 1

  @type t :: %__MODULE__{
          active: boolean,
          billing_scheme: binary,
          created_at: DateTime.t(),
          currency: binary,
          deleted_at: DateTime.t() | nil,
          id: binary,
          inserted_at: DateTime.t(),
          livemode: boolean,
          metadata: map | nil,
          nickname: binary,
          object: binary,
          product: Product.t(),
          product_id: binary,
          recurring_aggregate_usage: binary | nil,
          recurring_interval: binary | nil,
          recurring_interval_count: binary | nil,
          recurring_usage_type: binary | nil,
          tiers: [PriceTier.t()],
          tiers_mode: binary | nil,
          transform_quantity_divide_by: integer | nil,
          transform_quantity_round: integer | nil,
          type: binary,
          unit_amount: integer | nil,
          unit_amount_decimal: Decimal.t() | nil,
          updated_at: DateTime.t(),
          user: User.t(),
          user_id: binary
        }

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "prod", autogenerate: true}
  schema "prices" do
    field(:object, :string, default: "price")

    belongs_to(:user, User, type: Shortcode.Ecto.ID, prefix: "usr")
    belongs_to(:product, Product, type: Shortcode.Ecto.ID, prefix: "prod")

    field(:active, :boolean, default: true)
    field(:billing_scheme, :string, default: "per_unit")
    field(:created_at, :utc_datetime)
    field(:currency, :string)
    field(:livemode, :boolean)
    field(:metadata, :map, default: %{})
    field(:nickname, :string)
    field(:recurring_aggregate_usage, :string)
    field(:recurring_interval, :string)
    field(:recurring_interval_count, :integer)
    field(:recurring_usage_type, :string)
    has_many(:tiers, PriceTier)
    field(:tiers_mode, :string)
    field(:transform_quantity_divide_by, :integer)
    field(:transform_quantity_round, :string)
    field(:type, :string)
    field(:unit_amount, :integer)
    field(:unit_amount_decimal, :decimal)

    field(:deleted_at, :utc_datetime)
    timestamps(type: :utc_datetime)
  end

  @spec billing_schemes :: %{per_unit: binary(), tiered: binary()}
  def billing_schemes, do: %{per_unit: "per_unit", tiered: "tiered"}

  @spec currencies :: %{eur: binary(), ils: binary(), usd: binary()}
  def currencies, do: %{eur: "eur", ils: "ils", usd: "usd"}

  @spec recurring_aggregate_usages :: %{
          last_during_period: binary(),
          last_ever: binary(),
          max: binary(),
          sum: binary()
        }
  def recurring_aggregate_usages,
    do: %{
      last_during_period: "last_during_period",
      last_ever: "last_ever",
      max: "max",
      sum: "sum"
    }

  @spec recurring_intervals :: %{day: binary(), week: binary(), month: binary(), year: binary()}
  def recurring_intervals, do: %{day: "day", week: "week", month: "month", year: "year"}

  @spec recurring_usage_types :: %{licensed: binary(), metered: binary(), rated: binary()}
  def recurring_usage_types, do: %{licensed: "licensed", metered: "metered", rated: "rated"}

  @spec tiers_modes :: %{graduated: binary(), volume: binary()}
  def tiers_modes, do: %{graduated: "graduated", volume: "volume"}

  @spec transform_quantity_rounds :: %{down: binary(), up: binary()}
  def transform_quantity_rounds, do: %{down: "down", up: "up"}

  @spec types :: %{one_time: binary(), recurring: binary()}
  def types, do: %{one_time: "one_time", recurring: "recurring"}

  @spec create_changeset(Price.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = price, attrs) when is_map(attrs) do
    price
    |> cast(attrs, [
      :user_id,
      :product_id,
      :active,
      :billing_scheme,
      :created_at,
      :currency,
      :livemode,
      :metadata,
      :nickname,
      :recurring_aggregate_usage,
      :recurring_interval,
      :recurring_interval_count,
      :recurring_usage_type,
      :tiers_mode,
      :transform_quantity_divide_by,
      :transform_quantity_round,
      :unit_amount,
      :unit_amount_decimal
    ])
    |> validate_required([
      :user_id,
      :product_id,
      :active,
      :created_at,
      :currency,
      :livemode
    ])
    |> determine_type()
    |> validate_inclusion(:currency, Map.values(currencies()))
    |> validate_according_to_type()
    |> validate_transform_quantity()
    |> assoc_constraint(:product)
  end

  @spec update_changeset(Price.t(), map()) :: Ecto.Changeset.t()
  def update_changeset(%__MODULE__{} = price, attrs) when is_map(attrs) do
    price
    |> cast(attrs, [:active, :metadata, :nickname])
    |> validate_required([:active])
  end

  @spec delete_changeset(Price.t(), map()) :: Ecto.Changeset.t()
  def delete_changeset(%__MODULE__{} = price, attrs) when is_map(attrs) do
    price
    |> cast(attrs, [:deleted_at])
    |> validate_required([:deleted_at])
    |> AntlUtilsEcto.Changeset.validate_datetime_gte(:deleted_at, :created_at)
  end

  defp determine_type(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp determine_type(%Ecto.Changeset{valid?: true} = changeset) do
    [
      :recurring_aggregate_usage,
      :recurring_interval,
      :recurring_interval_count,
      :recurring_usage_type
    ]
    |> Enum.map(&get_field(changeset, &1))
    |> Enum.any?(&(not is_nil(&1)))
    |> case do
      true ->
        changeset |> put_change(:type, types().recurring)

      false ->
        changeset |> put_change(:type, types().one_time)
    end
  end

  defp validate_according_to_type(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_according_to_type(changeset) do
    %{one_time: one_time, recurring: recurring} = types()
    type = get_field(changeset, :type)

    case type do
      ^one_time ->
        billing_scheme = get_field(changeset, :billing_scheme) || billing_schemes().per_unit

        changeset
        |> AntlUtilsEcto.Changeset.validate_empty([:tiers, :tiers_mode],
          message: "can't be set when type is #{one_time}"
        )
        |> put_change(:billing_scheme, billing_scheme)
        |> validate_inclusion(:billing_scheme, [billing_schemes().per_unit],
          message: "is invalid when type is one_time"
        )
        |> AntlUtilsEcto.Changeset.validate_required_one_exclusive([
          :unit_amount,
          :unit_amount_decimal
        ])
        |> TailcallExtensionsEctoChangeset.equalize_integer_and_decimal_fields(
          :unit_amount,
          :unit_amount_decimal
        )

      ^recurring ->
        recurring_usage_type =
          get_field(changeset, :recurring_usage_type) || recurring_usage_types().licensed

        changeset
        |> put_change(:recurring_usage_type, recurring_usage_type)
        |> validate_inclusion(:recurring_usage_type, Map.values(recurring_usage_types()))
        |> validate_according_to_recurring_usage_type()
    end
  end

  defp validate_according_to_recurring_usage_type(%Ecto.Changeset{valid?: false} = changeset),
    do: changeset

  defp validate_according_to_recurring_usage_type(%Ecto.Changeset{valid?: true} = changeset) do
    %{licensed: licensed, metered: metered, rated: rated} = recurring_usage_types()
    recurring_usage_type = get_field(changeset, :recurring_usage_type)

    recurring_interval_count =
      get_field(changeset, :recurring_interval_count) ||
        @one_is_the_default_recurring_interval_count

    case recurring_usage_type do
      recurring_usage_type when recurring_usage_type in [licensed, metered] ->
        billing_scheme = get_field(changeset, :billing_scheme) || billing_schemes().per_unit

        case recurring_usage_type do
          ^licensed ->
            changeset
            |> AntlUtilsEcto.Changeset.validate_empty([:recurring_aggregate_usage],
              message: "can't be set when recurring_usage_type is #{licensed}"
            )

          ^metered ->
            recurring_aggregate_usage =
              get_field(changeset, :recurring_aggregate_usage, recurring_aggregate_usages().sum)

            changeset
            |> put_change(:recurring_aggregate_usage, recurring_aggregate_usage)
            |> validate_inclusion(
              :recurring_aggregate_usage,
              Map.values(recurring_aggregate_usages())
            )
        end
        |> put_change(:billing_scheme, billing_scheme)
        |> validate_inclusion(:billing_scheme, Map.values(billing_schemes()))
        |> validate_according_to_billing_scheme()

      ^rated ->
        changeset
        |> AntlUtilsEcto.Changeset.validate_empty(
          [
            :billing_scheme,
            :recurring_aggregate_usage,
            :tiers,
            :tiers_mode,
            :unit_amount,
            :unit_amount_decimal
          ],
          message: "can't be set when recurring_usage_type is #{rated}"
        )
    end
    |> put_change(:recurring_interval_count, recurring_interval_count)
    |> validate_required([:recurring_interval])
    |> validate_inclusion(:recurring_interval, Map.values(recurring_intervals()))
  end

  defp validate_according_to_billing_scheme(%Ecto.Changeset{valid?: false} = changeset),
    do: changeset

  defp validate_according_to_billing_scheme(changeset) do
    %{per_unit: per_unit, tiered: tiered} = billing_schemes()
    billing_scheme = get_field(changeset, :billing_scheme)

    case billing_scheme do
      ^per_unit ->
        changeset
        |> AntlUtilsEcto.Changeset.validate_required_one_exclusive([
          :unit_amount,
          :unit_amount_decimal
        ])
        |> TailcallExtensionsEctoChangeset.equalize_integer_and_decimal_fields(
          :unit_amount,
          :unit_amount_decimal
        )
        |> AntlUtilsEcto.Changeset.validate_empty([:tiers, :tiers_mode],
          message: "can't be set when billing_scheme is #{per_unit}"
        )

      ^tiered ->
        changeset
        |> validate_required([:tiers_mode])
        |> AntlUtilsEcto.Changeset.validate_empty([:unit_amount, :unit_amount_decimal],
          message: "can't be set when billing_scheme is #{tiered}"
        )
        |> validate_inclusion(:tiers_mode, Map.values(tiers_modes()))
        |> cast_assoc(:tiers,
          required: true,
          required_message: "can't be blank when billing_scheme is tiered",
          with: &PriceTier.changeset/2
        )
        |> validate_tiers_constaints()
    end
  end

  defp validate_transform_quantity(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_transform_quantity(%Ecto.Changeset{valid?: true} = changeset) do
    transform_quantity_divide_by = get_field(changeset, :transform_quantity_divide_by)
    transform_quantity_round = get_field(changeset, :transform_quantity_round)

    case {transform_quantity_divide_by, transform_quantity_round} do
      {nil, nil} ->
        changeset

      {divide_by, round} when is_integer(divide_by) and is_binary(round) ->
        changeset |> validate_number(:transform_quantity_divide_by, greater_than_or_equal_to: 2)

      {divide_by, nil} when is_integer(divide_by) ->
        changeset |> add_error(:transform_quantity_round, "can't be blank")

      {nil, round} when is_binary(round) ->
        changeset |> add_error(:transform_quantity_divide_by, "can't be blank")
    end
    |> validate_inclusion(:transform_quantity_round, Map.values(transform_quantity_rounds()))
  end

  # defp validate_tiers_constaints(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_tiers_constaints(%Ecto.Changeset{} = changeset) do
    changeset
    |> validate_tiers_are_uniq()
    |> validate_tiers_are_sorted()
  end

  defp validate_tiers_are_uniq(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_tiers_are_uniq(%Ecto.Changeset{valid?: true} = changeset) do
    validate_change(changeset, :tiers, fn :tiers, tiers_changeset ->
      up_to_list = tiers_changeset |> Enum.map(&get_field(&1, :up_to))

      if length(up_to_list) == length(Enum.uniq(up_to_list)) do
        []
      else
        [tiers: "must be uniq"]
      end
    end)
  end

  defp validate_tiers_are_sorted(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_tiers_are_sorted(%Ecto.Changeset{valid?: true} = changeset) do
    validate_change(changeset, :tiers, fn :tiers, tiers_changeset ->
      up_to_list = tiers_changeset |> Enum.map(&get_field(&1, :up_to))

      if up_to_list == Enum.sort(up_to_list) do
        []
      else
        [tiers: "must be sorted ascending by the up_to param"]
      end
    end)
  end
end
