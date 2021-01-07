defmodule Tailcall.Factory.Accounts.User do
  alias Tailcall.Accounts.Users.User

  defmacro __using__(_opts) do
    quote do
      def build(:user) do
        {:ok, performer} = Annacl.create_performer()

        %User{
          email: "email_#{System.unique_integer([:positive])}",
          name: "name_#{System.unique_integer([:positive])}",
          performer_id: performer.id
        }
      end
    end
  end
end
