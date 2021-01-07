defmodule Tailcall.Accounts.UsersTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Accounts.Users
  alias Tailcall.Accounts.Users.User

  describe "list_users/1" do
    test "list_users" do
      %{id: user_id} = insert!(:user)

      assert %{total: 1, data: [%{id: ^user_id}]} = Users.list_users()
    end

    test "filters" do
      user = insert!(:user)

      [
        [id: user.id],
        [id: [user.id]],
        [email: user.email],
        [name: user.name]
      ]
      |> Enum.each(fn filter ->
        assert %{total: 1, data: [_user]} = Users.list_users(filters: filter)
      end)

      [
        [id: shortcode_id()],
        [id: [shortcode_id()]],
        [email: "non existing email"],
        [name: "non existing name"]
      ]
      |> Enum.each(fn filter ->
        assert %{total: 0, data: []} = Users.list_users(filters: filter)
      end)
    end
  end

  describe "create_user/1" do
    test "when data is valid, creates the user" do
      user_params = params_for(:user)

      assert {:ok, %User{}} = Users.create_user(user_params)
    end

    test "when data is invalid, returns an error tuple with an invalid changeset" do
      user_params = params_for(:user, email: nil)

      assert {:error, changeset} = Users.create_user(user_params)

      refute changeset.valid?
    end
  end

  describe "get_user/1" do
    test "when the user exists, returns the user" do
      %{id: user_id} = insert!(:user)

      assert %User{id: ^user_id} = Users.get_user(user_id)
    end

    test "when user does not exist, returns nil" do
      assert is_nil(Users.get_user(shortcode_id()))
    end
  end

  describe "get_user!/1" do
    test "when the user exists, returns the user" do
      %{id: user_id} = insert!(:user)

      assert %User{id: ^user_id} = Users.get_user!(user_id)
    end

    test "when user does not exist, raises a Ecto.NoResultsError" do
      assert_raise Ecto.NoResultsError, fn ->
        Users.get_user!(shortcode_id())
      end
    end
  end

  describe "get_user_by/1" do
    test "when the user exists, returns the user" do
      %{id: user_id, email: email} = insert!(:user)

      assert %User{id: ^user_id} = Users.get_user_by(email: email)
    end

    test "when user does not exist, returns nil" do
      assert is_nil(Users.get_user_by(email: "email"))
    end
  end

  describe "user_exists?/1" do
    test "when the user exists, returns true" do
      user = insert!(:user)
      assert Users.user_exists?(user.id)
    end

    test "when user does not exist, returns false" do
      refute Users.user_exists?(shortcode_id())
    end
  end

  describe "update_user/2" do
    test "when data is valid, updates the user" do
      user_factory = insert!(:user)

      user_params = params_for(:user)

      assert {:ok, %User{} = user} = Users.update_user(user_factory, user_params)

      assert user.name == user_params.name
    end

    test "when data is invalid, returns an invalid changeset" do
      user = insert!(:user)

      assert {:error, changeset} = Users.update_user(user, %{name: nil})

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end
end
