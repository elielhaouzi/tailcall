defmodule Tailcall.Accounts.AccountsTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Accounts
  alias Tailcall.Accounts.ApiKeys.ApiKey

  describe "authenticate/1" do
    test "with valid existing key, returns the api_key" do
      api_key_factory = insert!(:api_key)
      api_key_usage_params = params_for(:api_key_usage)

      assert {:ok, %{api_key: %ApiKey{} = api_key, account: account}} =
               Accounts.authenticate(%{
                 "api_key" => api_key_factory.secret,
                 "ip_address" => api_key_usage_params.ip_address
               })

      assert api_key.id == api_key_factory.id
      assert account.id == api_key_factory.account_id

      api_key = Accounts.ApiKeys.get_api_key(api_key.id, includes: [:last_usage])
      assert api_key.last_used_ip_address == api_key_usage_params.ip_address
    end

    test "with invalid key returns :unauthorized" do
      assert {:error, :unauthorized} = Accounts.authenticate(%{"api_key" => 1})
    end

    test "with not existing key returns :unaunthorized" do
      assert {:error, :unauthorized} = Accounts.authenticate(%{"api_key" => "not existing key"})
    end

    test "with an expired existing key returns :forbidden" do
      api_key_params = build(:api_key) |> make_expired() |> params_for()
      api_key = insert!(:api_key, api_key_params)

      assert {:error, :forbidden} = Accounts.authenticate(%{"api_key" => api_key.secret})
    end
  end

  describe "livemode?/1" do
    test "return the livemode of the api_key" do
      livemode = Enum.random([true, false])
      api_key = insert!(:api_key, livemode: livemode)

      assert Accounts.livemode?(api_key) == livemode
    end
  end

  describe "account_exists?/1" do
    test "when the account exists, returns true" do
      account = insert!(:account)
      assert Accounts.account_exists?(account.id)
    end

    test "when account does not exist, returns false" do
      refute Accounts.account_exists?(shortcode_id())
    end
  end
end
