defmodule Tailcall.Factory.Audit.Event do
  alias Tailcall.Audit.Events.Event

  defmacro __using__(_opts) do
    quote do
      def build(:event) do
        %Event{
          user_id: shortcode_id(),
          api_version: "api_version",
          created_at: utc_now(),
          data: %{},
          livemode: false,
          type: "type_#{System.unique_integer([:positive])}",
          request_id: "request_id_#{System.unique_integer([:positive])}",
          resource_id: "resource_id_#{System.unique_integer([:positive])}",
          resource_type: "resource_type_#{System.unique_integer([:positive])}"
        }
      end
    end
  end
end
