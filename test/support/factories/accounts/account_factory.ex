defmodule Tailcall.Factory.Accounts.Account do
  alias Tailcall.Accounts.Account
  alias Tailcall.Accounts.InvoiceSettings

  defmacro __using__(_opts) do
    quote do
      def build(:account) do
        %Account{
          api_version: "api_version",
          created_at: utc_now(),
          invoice_settings: build(:invoice_settings),
          name: "name_#{System.unique_integer([:positive])}"
        }
      end

      def make_deleted(%Account{} = account), do: %{account | deleted_at: utc_now()}

      def build(:invoice_settings) do
        %InvoiceSettings{}
      end
    end
  end
end
