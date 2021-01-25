defmodule Tailcall.Accounts.AccountTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Accounts.Account

  describe "create_changeset/2" do
    test "only permitted keys are casted" do
      account_params = params_for(:account)

      changeset =
        Account.create_changeset(%Account{}, Map.merge(account_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()

      assert :api_version in changes_keys
      assert :created_at in changes_keys
      assert :name in changes_keys
      refute :new_key in changes_keys
    end

    test "when params are valid, returns an valid changeset" do
      account_params = params_for(:account)

      changeset = Account.create_changeset(%Account{}, account_params)

      assert changeset.valid?
      assert get_field(changeset, :api_version) == account_params.api_version
      assert get_field(changeset, :created_at) == account_params.created_at
      assert get_field(changeset, :name) == account_params.name
    end

    test "when required params are missing, returns an invalid changeset" do
      changeset = Account.create_changeset(%Account{}, %{})

      refute changeset.valid?
      # assert %{api_version: ["can't be blank"]} = errors_on(changeset)
      assert %{created_at: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_changeset/2" do
    test "only permitted keys are casted" do
      account = insert!(:account)
      account_params = params_for(:account, api_version: "new_api_version")

      changeset =
        Account.update_changeset(account, Map.merge(account_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()
      assert :api_version in changes_keys
      refute :created_at in changes_keys
      assert :name in changes_keys
      refute :new_key in changes_keys
    end

    test "when params are valid, returns an valid changeset" do
      account = insert!(:account)
      account_params = params_for(:account)

      changeset = Account.update_changeset(account, account_params)

      assert changeset.valid?
      assert get_field(changeset, :api_version) == account_params.api_version
      assert get_field(changeset, :name) == account_params.name
    end

    test "when required params are missing, returns an invalid changeset" do
      account = insert!(:account)

      changeset = Account.update_changeset(account, %{api_version: nil})

      refute changeset.valid?
      assert %{api_version: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "delete_changeset/2" do
    test "when deleted_at is valid, returns an valid changeset" do
      account = insert!(:account)

      utc_now = utc_now()

      changeset = Account.delete_changeset(account, %{deleted_at: utc_now})

      assert changeset.valid?
      assert get_field(changeset, :deleted_at) == utc_now
    end

    test "when deleted_at is nil, returns an invalid changeset" do
      account = insert!(:account)

      changeset = Account.delete_changeset(account, %{})

      refute changeset.valid?
      assert %{deleted_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "when deleted_at is before created_at, returns an invalid changeset" do
      account = insert!(:account, created_at: utc_now())

      changeset = Account.delete_changeset(account, %{deleted_at: utc_now() |> add(-1200)})

      refute changeset.valid?

      assert %{deleted_at: ["should be after or equal to created_at"]} = errors_on(changeset)
    end
  end
end
