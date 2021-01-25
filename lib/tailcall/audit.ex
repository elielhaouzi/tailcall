defmodule Tailcall.Audit do
  alias Tailcall.Audit.Events
  alias Tailcall.Audit.Events.Event

  @spec list_events(keyword) :: %{data: [Event.t()], total: integer}
  defdelegate list_events(opts \\ []), to: Events

  @spec new_event(%{:livemode => boolean, :account_id => binary, optional(atom) => any}) ::
          Event.t()
  defdelegate new_event(fields), to: Events

  @spec audit_event!(Event.t(), binary, map) :: Event.t()
  defdelegate audit_event!(event_schema, type, data), to: Events

  @spec audit_event_multi(Ecto.Multi.t(), Event.t(), binary, map | function) :: Ecto.Multi.t()
  defdelegate audit_event_multi(multi, event_schema, type, mixed \\ %{}), to: Events

  @spec get_event(binary, keyword) :: Event.t()
  defdelegate get_event(id, opts \\ []), to: Events
end
