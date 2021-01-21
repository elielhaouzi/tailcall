defmodule Tailcall.Factory.Core.Customers.Customer do
  alias Tailcall.Core.Customers.Customer
  alias Tailcall.Core.Customers.InvoiceSettings
  alias Tailcall.Core.Customers.InvoiceSettings.CustomField

  defmacro __using__(_opts) do
    quote do
      def build(:customer) do
        user = insert!(:user)

        %Customer{
          user_id: user.id,
          created_at: utc_now(),
          description: "description_#{System.unique_integer()}",
          email: "email_#{System.unique_integer()}",
          invoice_prefix: "invoice_prefix_#{System.unique_integer([:positive])}",
          invoice_settings: %{},
          livemode: false,
          email: "name_#{System.unique_integer()}",
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
