defmodule Tailcall.Factory.Accounts.Account do
  alias Tailcall.Accounts.Account
  alias Tailcall.Accounts.InvoiceSettings

  defmacro __using__(_opts) do
    quote do
      def build(:account, attrs) do
        %Account{
          api_version: "api_version",
          created_at: utc_now(),
          invoice_settings: build(:account_invoice_settings),
          name: "name_#{System.unique_integer()}"
        }
        |> struct!(attrs)
      end

      def make_deleted(%Account{} = account), do: %{account | deleted_at: utc_now()}

      def build(:account_invoice_settings, attrs) do
        %InvoiceSettings{
          invoice_prefix: "invoice_prefix_#{System.unique_integer()}"
        }
        |> struct!(attrs)
      end
    end
  end
end
