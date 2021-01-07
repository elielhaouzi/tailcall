defmodule Tailcall.Accounts.ApiKeys.ApiKeyUsageTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Accounts.ApiKeys.ApiKeyUsage

  describe "changeset/2" do
    test "only permitted_keys are casted" do
      api_key_usage_params = params_for(:api_key_usage, api_key_id: uuid())

      changeset =
        ApiKeyUsage.changeset(
          %ApiKeyUsage{},
          Map.merge(api_key_usage_params, %{new_key: "value"})
        )

      changes_keys = changeset.changes |> Map.keys()

      assert :api_key_id in changes_keys
      assert :ip_address in changes_keys
      assert :request_id in changes_keys
      assert :used_at in changes_keys
      refute :new_key in changes_keys
    end

    test "when required params are missing, returns an invalid changeset" do
      changeset = ApiKeyUsage.changeset(%ApiKeyUsage{}, %{})

      refute changeset.valid?
      assert %{api_key_id: ["can't be blank"]} = errors_on(changeset)
      assert %{used_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "when params are valid, return a valid changeset" do
      api_key_usage_params = params_for(:api_key_usage, api_key_id: uuid())

      changeset = ApiKeyUsage.changeset(%ApiKeyUsage{}, api_key_usage_params)

      assert changeset.valid?
      assert get_field(changeset, :api_key_id) == api_key_usage_params.api_key_id
      assert get_field(changeset, :ip_address) == api_key_usage_params.ip_address
      assert get_field(changeset, :request_id) == api_key_usage_params.request_id
      assert get_field(changeset, :used_at) == api_key_usage_params.used_at
    end
  end
end
