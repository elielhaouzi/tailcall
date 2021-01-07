defmodule Billing.Audit.Events do
  @moduledoc """
  The Events context.
  """
  alias Ecto.Multi

  alias Billing.Repo

  alias Billing.Audit.Events.{Event, EventQueryable}

  @default_sort_field :id
  @default_sort_order :desc
  @default_page_number 1
  @default_page_size 100

  @required_data_keys_according_to_type %{
    "product.created" => ~w(id)
  }

  defmodule InvalidParameterError do
    defexception [:message]
  end

  @spec list_events(keyword) :: %{data: [Event.t()], total: integer}
  def list_events(opts \\ []) do
    sort_field = Keyword.get(opts, :sort_field, @default_sort_field)
    sort_order = Keyword.get(opts, :sort_order, @default_sort_order)

    page_number = Keyword.get(opts, :page_number, @default_page_number)
    page_size = Keyword.get(opts, :page_size, @default_page_size)

    query = event_queryable(opts)

    count = query |> Repo.aggregate(:count, :id)

    events =
      query
      |> EventQueryable.sort(%{field: sort_field, order: sort_order})
      |> EventQueryable.paginate(page_number, page_size)
      |> Repo.all()

    %{total: count, data: events}
  end

  @doc """
  Returns an audit event struct with pre-filled fields.
  """
  @spec new(%{:livemode => boolean, :user_id => binary, optional(atom) => any}) :: Event.t()
  def new(%{livemode: _, user_id: _} = fields) do
    struct!(Event, fields)
  end

  @spec audit!(Event.t(), binary, map) :: any
  def audit!(%Event{} = event_schema, type, data) do
    Repo.insert!(build!(event_schema, type, data))
  end

  def multi(multi, %Event{} = event_schema, type, fun) when is_function(fun, 2) do
    Ecto.Multi.run(multi, :audit_event, fn _repo, changes ->
      {:ok, audit!(fun.(event_schema, changes), type, %{})}
    end)
  end

  @spec multi(Ecto.Multi.t(), Event.t(), binary, map) :: Ecto.Multi.t()
  def multi(multi, %Event{} = event_schema, type, data) when is_binary(type) and is_map(data) do
    Multi.run(multi, :audit_event, fn _repo, _changes ->
      {:ok, audit!(event_schema, type, data)}
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
end
