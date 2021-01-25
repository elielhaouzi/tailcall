defmodule Tailcall.Factory.Users.User do
  alias Tailcall.Users.User

  defmacro __using__(_opts) do
    quote do
      def build(:user) do
        {:ok, performer} = Annacl.create_performer()

        %User{
          created_at: utc_now(),
          email: "email_#{System.unique_integer([:positive])}",
          name: "name_#{System.unique_integer([:positive])}",
          performer_id: performer.id
        }
      end

      def make_deleted(%User{} = user), do: %{user | deleted_at: utc_now()}

      def make_superadmin(%User{} = user),
        do: user |> Annacl.assign_role!(Annacl.superadmin_role_name())
    end
  end
end
