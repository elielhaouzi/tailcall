defmodule Tailcall.Audit.Events do
  @moduledoc """
  The Events context.
  """
  import Ecto.Query, only: [order_by: 2]

  alias Ecto.Multi

  alias Tailcall.Repo

  alias Tailcall.Audit.Events.{Event, EventQueryable}

  @default_order_by [desc: :id]
  @default_page_number 1
  @default_page_size 100

  @required_data_keys_according_to_type %{
    "product.created" => ~w(id)
  }

  @spec list_events(keyword) :: %{data: [Event.t()], total: integer}
  def list_events(opts \\ []) do
    page_number = Keyword.get(opts, :page_number, @default_page_number)
    page_size = Keyword.get(opts, :page_size, @default_page_size)
    order_by_fields = list_order_by_fields(opts)

    query = event_queryable(opts)

    count = query |> Repo.aggregate(:count, :id)

    events =
      query
      |> order_by(^order_by_fields)
      |> EventQueryable.paginate(page_number, page_size)
      |> Repo.all()

    %{data: events, total: count}
  end

  @doc """
  Returns an audit event struct with pre-filled fields.
  """
  @spec new_event(%{:livemode => boolean, :account_id => binary, optional(atom) => any}) ::
          Event.t()
  def new_event(%{livemode: _, account_id: _} = fields) do
    struct!(Event, fields)
  end

  @spec audit_event!(Event.t(), binary, map) :: any
  def audit_event!(%Event{} = event_schema, type, data \\ %{}) do
    Repo.insert!(build!(event_schema, type, data))
  end

  @spec audit_event_multi(Ecto.Multi.t(), Event.t(), binary, map | function) :: Ecto.Multi.t()
  def audit_event_multi(multi, event_schema, type, mixed \\ %{})

  def audit_event_multi(multi, %Event{} = event_schema, type, fun) when is_function(fun, 2) do
    Ecto.Multi.run(multi, :audit_event, fn _repo, changes ->
      {:ok, audit_event!(fun.(event_schema, changes), type, %{})}
    end)
  end

  def audit_event_multi(multi, %Event{} = event_schema, type, data)
      when is_binary(type) and is_map(data) do
    Multi.run(multi, :audit_event, fn _repo, _changes ->
      {:ok, audit_event!(event_schema, type, data)}
    end)
  end

  @spec get_event(binary, keyword()) :: Event.t() | nil
  def get_event(id, opts \\ []) when is_binary(id) do
    opts
    |> Keyword.put(:filters, id: id)
    |> event_queryable()
    |> Repo.one()
  end

  defp event_queryable(opts) do
    filters = Keyword.get(opts, :filters, [])

    EventQueryable.queryable()
    |> EventQueryable.filter(filters)
  end

  defp build!(%Event{} = event, type, data) when is_binary(type) and is_map(data) do
    Event.changeset(event, %{
      created_at: DateTime.utc_now(),
      data: Map.merge(event.data || %{}, data),
      request_id: Logger.metadata()[:request_id],
      type: type
    })
    |> Ecto.Changeset.validate_inclusion(:type, Map.keys(@required_data_keys_according_to_type))
    |> validate_required_data_keys_according_to_type()
  end

  defp validate_required_data_keys_according_to_type(%Ecto.Changeset{valid?: false} = changeset),
    do: changeset

  defp validate_required_data_keys_according_to_type(%Ecto.Changeset{} = changeset) do
    type = Ecto.Changeset.get_field(changeset, :type)
    data = Ecto.Changeset.get_field(changeset, :data)

    expected_keys = Map.fetch!(@required_data_keys_according_to_type, type)

    actual_keys = data |> Map.keys() |> Enum.map(&to_string/1)

    case expected_keys -- actual_keys do
      [_ | _] = missing_keys ->
        changeset
        |> Ecto.Changeset.add_error(
          :type,
          "missing keys #{inspect(missing_keys)} for type #{type} in #{inspect(data)}"
        )

      _ ->
        changeset
    end
  end

  defp list_order_by_fields(opts) do
    Keyword.get(opts, :order_by_fields, [])
    |> case do
      [] -> @default_order_by
      [_ | _] = order_by_fields -> order_by_fields
    end
  end
end
