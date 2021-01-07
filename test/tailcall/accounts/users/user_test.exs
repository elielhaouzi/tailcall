defmodule Tailcall.Accounts.Users.UserTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Accounts.Users.User

  describe "create_changeset/2" do
    test "only permitted keys are casted" do
      user_params = params_for(:user)

      changeset = User.create_changeset(%User{}, Map.merge(user_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()

      assert :email in changes_keys
      assert :name in changes_keys
      refute :new_key in changes_keys
    end

    test "when params are valid, returns an valid changeset" do
      user_params = params_for(:user)

      changeset = User.create_changeset(%User{}, user_params)

      assert changeset.valid?
    end

    test "when required params are missing, returns an invalid changeset" do
      user_params = params_for(:user, email: nil)

      changeset = User.create_changeset(%User{}, user_params)

      refute changeset.valid?
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_changeset/2" do
    test "only permitted keys are casted" do
      user = insert!(:user)
      user_params = params_for(:user)

      changeset = User.update_changeset(user, Map.merge(user_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()
      assert :name in changes_keys
      refute :email in changes_keys
      refute :new_key in changes_keys
    end

    test "when required params are missing, returns an invalid changeset" do
      user = insert!(:user)

      changeset = User.update_changeset(user, %{name: nil})

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end
end
