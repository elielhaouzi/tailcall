defmodule Tailcall.Factory.Accounts.ApiKey do
  alias Tailcall.Accounts.ApiKeys.{ApiKey, ApiKeyUsage}

  defmacro __using__(_opts) do
    quote do
      def build(:api_key) do
        %{id: account_id} = insert!(:account)

        %ApiKey{
          account_id: account_id,
          created_at: utc_now(),
          livemode: false,
          secret: Tailcall.Accounts.ApiKeys.generate_secret_key("secret", false)
        }
        |> type_secret()
        |> type_publishable()
      end

      def type_secret(%ApiKey{} = api_key), do: %{api_key | type: "secret"}
      def type_publishable(%ApiKey{} = api_key), do: %{api_key | type: "publishable"}
      def make_expired(%ApiKey{} = api_key), do: %{api_key | expired_at: utc_now()}

      def build(:api_key_usage) do
        %ApiKeyUsage{
          ip_address: "127.0.0.1",
          request_id: "request_id",
          used_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
        }
      end
    end
  end
end
