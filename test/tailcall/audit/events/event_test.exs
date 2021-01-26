defmodule Tailcall.Audit.Events.EventTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Audit.Events.Event

  describe "changeset/2" do
    test "only permitted_keys are casted" do
      event_params = params_for(:event)

      changeset =
        Event.changeset(
          %Event{},
          Map.merge(event_params, %{new_key: "value"})
        )

      changes_keys = changeset.changes |> Map.keys()

      assert :account_id in changes_keys
      assert :api_version in changes_keys
      assert :created_at in changes_keys
      assert :data in changes_keys
      assert :livemode in changes_keys
      assert :request_id in changes_keys
      assert :resource_id in changes_keys
      assert :resource_type in changes_keys
      assert :type in changes_keys
      refute :new_key in changes_keys
    end

    test "when required params are missing, returns an invalid changeset" do
      changeset = Event.changeset(%Event{}, %{})

      refute changeset.valid?
      assert %{account_id: ["can't be blank"]} = errors_on(changeset)
      assert %{created_at: ["can't be blank"]} = errors_on(changeset)
      assert %{data: ["can't be blank"]} = errors_on(changeset)
      assert %{livemode: ["can't be blank"]} = errors_on(changeset)
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "when params are valid, return a valid changeset" do
      event_params = params_for(:event)

      changeset = Event.changeset(%Event{}, event_params)

      assert changeset.valid?

      assert get_field(changeset, :account_id) == event_params.account_id
      assert get_field(changeset, :created_at) == event_params.created_at
      assert get_field(changeset, :data) == event_params.data
      assert get_field(changeset, :livemode) == event_params.livemode
      assert get_field(changeset, :request_id) == event_params.request_id
      assert get_field(changeset, :resource_id) == event_params.resource_id
      assert get_field(changeset, :resource_type) == event_params.resource_type
      assert get_field(changeset, :type) == event_params.type
    end
  end
end
