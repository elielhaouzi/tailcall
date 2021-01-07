defmodule Tailcall.Audit.EventsTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Audit.Events
  alias Tailcall.Audit.Events.Event

  describe "list_events/1" do
    test "returns the list of events ordered by the sequence descending" do
      %{id: id_1} = insert!(:event, created_at: utc_now())
      %{id: id_2} = insert!(:event, created_at: utc_now() |> add(1_000))

      assert %{data: [%{id: ^id_2}, %{id: ^id_1}], total: 2} = Events.list_events()
    end

    test "filters" do
      event = insert!(:event)

      [
        [id: event.id],
        [user_id: event.user_id],
        [api_version: event.api_version],
        [livemode: event.livemode],
        [request_id: event.request_id],
        [resource_id: event.resource_id],
        [resource_type: event.resource_type],
        [type: event.type]
      ]
      |> Enum.each(fn filter ->
        assert %{data: [_event], total: 1} = Events.list_events(filters: filter)
      end)

      [
        [id: shortcode_id()],
        [user_id: shortcode_id()],
        [api_version: "api-version"],
        [livemode: !event.livemode],
        [request_id: "request-id"],
        [resource_id: "resource_id"],
        [resource_type: "resource_type"],
        [type: "type"]
      ]
      |> Enum.each(fn filter ->
        assert %{data: [], total: 0} = Events.list_events(filters: filter)
      end)
    end
  end

  describe "audit_event!/3" do
    test "when data is valid, create an audit event" do
      Logger.metadata(request_id: "request_id")
      event_schema = Events.new(%{user_id: shortcode_id("usr"), livemode: false})

      audit_event = Events.audit!(event_schema, "product.created", %{id: "product_id"})
      assert %Event{} = audit_event

      assert audit_event.user_id == event_schema.user_id
      refute is_nil(audit_event.created_at)
      assert audit_event.api_version == event_schema.api_version
      assert audit_event.livemode == event_schema.livemode
      assert audit_event.data == %{id: "product_id"}
      assert audit_event.request_id == "request_id"
      assert audit_event.type == "product.created"
    end

    test "when data is invalid, raises an Ecto.InvalidChangesetError" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        Events.audit!(%Event{}, "product.created", %{id: "product_id"})
      end
    end

    test "when non-existing types is specified, raises an Ecto.InvalidChangesetError" do
      event_schema = Events.new(%{user_id: shortcode_id("usr"), livemode: false})

      assert_raise Ecto.InvalidChangesetError, fn ->
        Events.audit!(event_schema, "event_type", %{id: "product_id"})
      end
    end

    test "when one of required key is missing, raises an Ecto.InvalidChangesetError" do
      event_schema = Events.new(%{user_id: shortcode_id("usr"), livemode: false})

      assert_raise Ecto.InvalidChangesetError, fn ->
        Events.audit!(event_schema, "product.created", %{})
      end
    end
  end

  describe "multi/4" do
    test "create a multi operation with params" do
      Logger.metadata(request_id: "request_id")
      event_schema = Events.new(%{livemode: false, user_id: shortcode_id("usr")})

      multi =
        Ecto.Multi.new()
        |> Events.multi(event_schema, "product.created", %{id: "product_id"})

      assert %Ecto.Multi{} = multi

      assert {:ok, %{audit_event: %Event{} = audit_event}} = Repo.transaction(multi)

      assert audit_event.user_id == event_schema.user_id
      refute is_nil(audit_event.created_at)
      assert audit_event.api_version == event_schema.api_version
      assert audit_event.livemode == event_schema.livemode
      assert audit_event.data == %{id: "product_id"}
      assert audit_event.request_id == "request_id"
      assert audit_event.type == "product.created"
    end

    test "creates an ecto multi operation with a function" do
      event_schema = Events.new(%{livemode: false, user_id: shortcode_id("usr")})
      any_schema = Event.changeset(%Event{}, params_for(:event))

      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:any_schema, any_schema)
        |> Events.multi(
          event_schema,
          "product.created",
          fn audit_event_schema, changes ->
            assert %Event{} = audit_event_schema
            assert %{any_schema: %Event{}} = changes

            %{audit_event_schema | data: %{id: changes.any_schema.id}}
          end
        )

      assert {:ok, %{audit_event: %Event{} = audit_event, any_schema: any_schema}} =
               Repo.transaction(multi)

      assert audit_event.type == "product.created"
      assert audit_event.data == %{id: any_schema.id}
    end
  end

  describe "get_event/2" do
    test "when the event exists, returns the api_key" do
      %{id: event_id} = insert!(:event)

      assert %Event{id: ^event_id} = Events.get_event(event_id)
    end

    test "when then event does not exist, returns nil" do
      assert is_nil(Events.get_event(shortcode_id()))
    end
  end
end
