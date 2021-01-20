defmodule Tailcall.Factory.Billing.Product do
  alias Tailcall.Billing.Products.Product

  defmacro __using__(_opts) do
    quote do
      def build(:product) do
        user = insert!(:user)

        %Product{
          user_id: user.id,
          description: "description_#{System.unique_integer()}",
          caption: "caption_#{System.unique_integer()}",
          created_at: utc_now(),
          livemode: false,
          metadata: %{},
          name: "name_#{System.unique_integer()}",
          statement_descriptor: "statement_descriptor_#{System.unique_integer()}",
          type: "service",
          unit_label: "unit_label_#{System.unique_integer()}",
          url: "url_#{System.unique_integer()}"
        }
        |> make_active()
      end

      def make_active(%Product{} = product), do: %{product | active: true}
      def make_inactive(%Product{} = product), do: %{product | active: false}
      def make_deleted(%Product{} = product), do: %{product | deleted_at: utc_now()}
    end
  end
end
