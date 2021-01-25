defmodule Tailcall.Users.UserTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Users.User

  describe "create_changeset/2" do
    test "only permitted keys are casted" do
      user_params = params_for(:user)

      changeset = User.create_changeset(%User{}, Map.merge(user_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()

      assert :created_at in changes_keys
      assert :email in changes_keys
      assert :name in changes_keys
      refute :new_key in changes_keys
    end

    test "when params are valid, returns an valid changeset" do
      user_params = params_for(:user)

      changeset = User.create_changeset(%User{}, user_params)

      assert changeset.valid?
      assert get_field(changeset, :created_at) == user_params.created_at
      assert get_field(changeset, :email) == user_params.email
      assert get_field(changeset, :name) == user_params.name
    end

    test "when required params are missing, returns an invalid changeset" do
      changeset = User.create_changeset(%User{}, %{})

      refute changeset.valid?
      assert %{created_at: ["can't be blank"]} = errors_on(changeset)
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

    test "when params are valid, returns an valid changeset" do
      user = insert!(:user)
      user_params = params_for(:user)

      changeset = User.update_changeset(user, user_params)

      assert changeset.valid?
      assert get_field(changeset, :name) == user_params.name
    end

    test "when required params are missing, returns an invalid changeset" do
      user = insert!(:user)

      changeset = User.update_changeset(user, %{name: nil})

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "delete_changeset/2" do
    test "when deleted_at is valid, returns an valid changeset" do
      user = insert!(:user)

      utc_now = utc_now()

      changeset = User.delete_changeset(user, %{deleted_at: utc_now})

      assert changeset.valid?
      assert get_field(changeset, :deleted_at) == utc_now
    end

    test "when deleted_at is nil, returns an invalid changeset" do
      user = insert!(:user)

      changeset = User.delete_changeset(user, %{})

      refute changeset.valid?
      assert %{deleted_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "when deleted_at is before created_at, returns an invalid changeset" do
      user = insert!(:user, created_at: utc_now())

      changeset = User.delete_changeset(user, %{deleted_at: utc_now() |> add(-1200)})

      refute changeset.valid?

      assert %{deleted_at: ["should be after or equal to created_at"]} = errors_on(changeset)
    end
  end
end
