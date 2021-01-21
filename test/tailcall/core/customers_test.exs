# defmodule Payments.CustomersTest do
#   use ExUnit.Case, async: true
#   use Payments.DataCase

#   alias Payments.Accounts.Users.User
#   alias Payments.Customers
#   alias Payments.Customers.Customer

#   @uuids %{0 => "00000000-0000-0000-0000-000000000000"}

#   @datetime_1 DateTime.from_naive!(~N[2018-05-24 12:27:48], "Etc/UTC")

#   setup :verify_on_exit!

#   describe "create_customer/1" do
#     test "with invalid data, returns an error tuple with an invalid changeset" do
#       customer_params = params_for(:customer, livemode: nil)

#       assert {:error, changeset} =
#                Customers.create_customer(%User{id: @uuids[0]}, customer_params)

#       refute changeset.valid?
#     end

#     test "when user does not exist, returns an error tuple with an invalid changeset" do
#       user = insert(:user)
#       user_id = user.id
#       AccountsMock |> expect(:user_exists?, fn ^user_id -> false end)

#       customer_params = params_for(:customer)

#       assert {:error, changeset} = Customers.create_customer(%User{id: user_id}, customer_params)

#       refute changeset.valid?
#       assert %{user: ["does not exist"]} = errors_on(changeset)
#     end

#     test "when data is valid, creates the customer" do
#       user = insert(:user)
#       AccountsMock |> expect(:user_exists?, fn _ -> true end)

#       customer_params = params_for(:customer, user_id: user.id)

#       assert {:ok, %Customer{} = customer} = Customers.create_customer(user, customer_params)
#       assert customer.name == customer_params.name
#     end
#   end

#   describe "get_customer/1" do
#     test "when customer does not exist, returns nil" do
#       assert is_nil(Customers.get_customer(@uuids[0]))
#     end

#     test "when customer exists, returns the customer" do
#       customer_factory = insert(:customer)

#       customer = Customers.get_customer(customer_factory.id)
#       assert %Customer{} = customer
#       assert customer.id == customer_factory.id
#     end
#   end

#   describe "customer_exists?/1" do
#     test "when customer does not exist, returns false" do
#       refute Customers.customer_exists?(@uuids[0])
#     end

#     test "when customer exists, returns it" do
#       customer = insert(:customer)

#       assert Customers.customer_exists?(customer.id)
#     end
#   end

#   describe "update_customer/2" do
#     test "when customer is soft deleted, raise a FunctionClauseError" do
#       customer = insert(:customer, deleted_at: @datetime_1)

#       assert_raise FunctionClauseError, fn ->
#         Customers.update_customer(customer, %{active: false})
#       end
#     end

#     test "when data is valid, update the customer" do
#       customer = insert(:customer)

#       {:ok, %Customer{} = customer} = Customers.update_customer(customer, %{name: "new name"})
#       assert customer.name == "new name"
#     end
#   end

#   describe "delete_customer/2" do
#     test "with a customer that is already soft deleted, raises a FunctionClauseError" do
#       customer = insert(:customer, deleted_at: @datetime_1)

#       assert_raise FunctionClauseError, fn ->
#         Customers.delete_customer(customer, @datetime_1)
#       end
#     end

#     test "with a valid customer, soft deletes the customer" do
#       customer_factory = insert(:customer)

#       assert {:ok, %Customer{} = customer} =
#                Customers.delete_customer(customer_factory, @datetime_1)

#       assert customer.deleted_at == @datetime_1
#     end
#   end
# end
