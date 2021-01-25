defmodule Tailcall.Factory.Core.Customers.Customer do
  alias Tailcall.Core.Customers.Customer
  alias Tailcall.Core.Customers.InvoiceSettings
  alias Tailcall.Core.Customers.InvoiceSettings.CustomField

  defmacro __using__(_opts) do
    quote do
      def build(:customer) do
        account = insert!(:account)

        %Customer{
          account_id: account.id,
          currency: "ils",
          created_at: utc_now(),
          description: "description_#{System.unique_integer()}",
          email: "email_#{System.unique_integer()}",
          invoice_prefix: "invoice_prefix_#{System.unique_integer([])}",
          # invoice_settings: build(:invoice_settings),
          livemode: false,
          name: "name_#{System.unique_integer()}",
          next_invoice_sequence: 1,
          phone: "phone_#{System.unique_integer()}"
        }
      end

      def make_deleted(%Customer{} = customer), do: %{customer | deleted_at: utc_now()}

      def build(:invoice_settings) do
        %InvoiceSettings{
          custom_fields: [build(:custom_field)],
          footer: "footer_#{System.unique_integer()}"
        }
      end

      def build(:custom_field) do
        %CustomField{
          name: "name_#{System.unique_integer()}",
          value: "value_#{System.unique_integer()}"
        }
      end
    end
  end
end
