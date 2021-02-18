defmodule Tailcall.Factory.Core.Customers.Customer do
  alias Tailcall.Core.Customers.Customer
  alias Tailcall.Core.Customers.InvoiceSettings
  alias Tailcall.Core.Customers.InvoiceSettings.CustomField

  defmacro __using__(_opts) do
    quote do
      def build(:customer, attrs) do
        {account_id, attrs} = Keyword.pop(attrs, :account_id)
        account_id = account_id || Map.get(insert!(:account), :id)

        %Customer{
          account_id: account_id,
          currency: "ils",
          created_at: utc_now(),
          description: "description_#{System.unique_integer()}",
          email: "email_#{System.unique_integer()}",
          invoice_prefix: "invoice_prefix_#{System.unique_integer([])}",
          invoice_settings: build(:customer_invoice_settings),
          livemode: false,
          name: "name_#{System.unique_integer()}",
          next_invoice_sequence: 1,
          phone: "phone_#{System.unique_integer()}",
          preferred_locales: ["he"]
        }
        |> struct!(attrs)
      end

      def make_deleted(%Customer{} = customer), do: %{customer | deleted_at: utc_now()}

      def build(:customer_invoice_settings, attrs) do
        %InvoiceSettings{
          custom_fields: [build(:customer_invoice_settings_custom_field) |> Map.from_struct()],
          footer: "footer_#{System.unique_integer()}"
        }
        |> struct!(attrs)
      end

      def build(:customer_invoice_settings_custom_field, attrs) do
        %CustomField{
          name: "name_#{System.unique_integer()}",
          value: "value_#{System.unique_integer()}"
        }
        |> struct!(attrs)
      end
    end
  end
end
