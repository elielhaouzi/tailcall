defmodule Tailcall.Accounts.ApiKeysTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Accounts.ApiKeys
  alias Tailcall.Accounts.ApiKeys.{ApiKey, ApiKeyUsage}

  describe "list_api_keys/1" do
    test "returns the list of api_keys ordered by the sequence ascending" do
      %{id: id_1} = insert!(:api_key, created_at: utc_now())
      %{id: id_2} = insert!(:api_key, created_at: utc_now() |> add(1_000))

      assert [%{id: ^id_1}, %{id: ^id_2}] = ApiKeys.list_api_keys()
    end

    test "filters" do
      api_key = insert!(:api_key)

      [
        [id: api_key.id],
        [livemode: api_key.livemode],
        [secret: api_key.secret],
        [type: api_key.type]
      ]
      |> Enum.each(fn filter ->
        assert [_api_key] = ApiKeys.list_api_keys(filters: filter)
      end)

      [
        [id: shortcode_id()],
        [livemode: !api_key.livemode],
        [secret: "secret"],
        [type: "type"]
      ]
      |> Enum.each(fn filter ->
        assert [] = ApiKeys.list_api_keys(filters: filter)
      end)
    end

    test "includes" do
      api_key_factory = insert!(:api_key)
      insert!(:api_key_usage, api_key_id: api_key_factory.id)
      last_api_key_usage = insert!(:api_key_usage, api_key_id: api_key_factory.id)

      assert [api_key] = ApiKeys.list_api_keys()
      refute Ecto.assoc_loaded?(api_key.account)
      assert is_nil(api_key.last_used_at)
      assert is_nil(api_key.last_used_ip_address)

      assert [api_key] = ApiKeys.list_api_keys(includes: [:last_usage, :account])
      assert api_key.account.id == api_key_factory.account_id
      assert api_key.last_used_at == last_api_key_usage.used_at
      assert api_key.last_used_ip_address == last_api_key_usage.ip_address
    end
  end

  describe "create_api_key/1" do
    test "when data is valid, creates the api_key" do
      account = insert!(:account)
      api_key_params = params_for(:api_key, account_id: account.id, expired_at: utc_now())

      assert {:ok, %ApiKeys.ApiKey{} = api_key} = ApiKeys.create_api_key(api_key_params)
      assert api_key.account_id == api_key_params.account_id
      assert api_key.created_at == api_key_params.created_at
      assert api_key.expired_at == api_key_params.expired_at
      assert api_key.livemode == api_key_params.livemode
      assert api_key.secret == api_key_params.secret
      assert api_key.type == api_key_params.type
    end

    test "when account does not exist, returns an error tuple with an invalid changeset" do
      api_key_params = params_for(:api_key, account_id: shortcode_id())

      assert {:error, changeset} = ApiKeys.create_api_key(api_key_params)

      refute changeset.valid?
      assert %{account: ["does not exist"]} = errors_on(changeset)
    end

    test "when data is invalid, returns an error tuple with an invalid changeset" do
      api_key_params = params_for(:api_key, account_id: nil)

      assert {:error, changeset} = ApiKeys.create_api_key(api_key_params)

      refute changeset.valid?
    end
  end

  describe "get_api_key/2" do
    test "when the api_key exists, returns the api_key" do
      %{id: api_key_id} = insert!(:api_key)

      assert %ApiKey{id: ^api_key_id} = ApiKeys.get_api_key(api_key_id)
    end

    test "include" do
      api_key_factory = insert!(:api_key)
      insert!(:api_key_usage, api_key_id: api_key_factory.id)
      last_api_key_usage = insert!(:api_key_usage, api_key_id: api_key_factory.id)

      api_key = ApiKeys.get_api_key(api_key_factory.id)
      refute Ecto.assoc_loaded?(api_key.account)
      assert is_nil(api_key.last_used_at)
      assert is_nil(api_key.last_used_ip_address)

      api_key = ApiKeys.get_api_key(api_key_factory.id, includes: [:last_usage, :account])
      assert api_key.account.id == api_key_factory.account_id
      assert api_key.last_used_at == last_api_key_usage.used_at
      assert api_key.last_used_ip_address == last_api_key_usage.ip_address
    end

    test "when key does not exist, returns nil" do
      assert is_nil(ApiKeys.get_api_key(shortcode_id()))
    end
  end

  describe "get_api_key_by/2" do
    test "when the secret exists, returns the api_key" do
      _ = insert!(:api_key)
      %{id: api_key_id, secret: secret} = insert!(:api_key)

      assert %ApiKey{id: ^api_key_id} = ApiKeys.get_api_key_by(secret: secret)
    end

    test "include" do
      api_key_factory = insert!(:api_key)
      insert!(:api_key_usage, api_key_id: api_key_factory.id)
      last_api_key_usage = insert!(:api_key_usage, api_key_id: api_key_factory.id)

      assert api_key = ApiKeys.get_api_key_by(secret: api_key_factory.secret)
      refute Ecto.assoc_loaded?(api_key.account)
      assert is_nil(api_key.last_used_at)
      assert is_nil(api_key.last_used_ip_address)

      assert api_key =
               ApiKeys.get_api_key_by([secret: api_key_factory.secret],
                 includes: [:last_usage, :account]
               )

      assert api_key.account.id == api_key_factory.account_id
      assert api_key.last_used_at == last_api_key_usage.used_at
      assert api_key.last_used_ip_address == last_api_key_usage.ip_address
    end

    test "when key does not exist, returns nil" do
      assert is_nil(ApiKeys.get_api_key_by(secret: "secret"))
    end
  end

  describe "roll/1" do
    test "when rolling the api_key, closes the given api_key at expires_at, creates a new one and return it" do
      api_key = insert!(:api_key)
      expires_at = utc_now() |> add(6 * 24 * 3600)

      assert {:ok, %ApiKey{} = new_api_key} = ApiKeys.roll_api_key(api_key, expires_at)

      api_key = Repo.reload!(api_key)
      assert api_key.expired_at == expires_at

      assert new_api_key.id != api_key.id
      assert new_api_key.secret != api_key.secret
      assert new_api_key.created_at != expires_at
      assert new_api_key.account_id == api_key.account_id
      assert new_api_key.type == api_key.type

      assert_in_delta DateTime.to_unix(new_api_key.created_at), DateTime.to_unix(utc_now()), 100
      assert is_nil(new_api_key.expired_at)
    end

    test "when expired_at is more than 7 days, return an error tuple with a invalid changeset" do
      api_key = insert!(:api_key)

      assert {:error, %Ecto.Changeset{} = changeset} =
               ApiKeys.roll_api_key(api_key, utc_now() |> add(8 * 24 * 3600))

      refute changeset.valid?
    end
  end

  describe "refute_access/1" do
    test "when api_keys is not expired, expire the api_key" do
      api_key = insert!(:api_key)
      utc_now = utc_now()

      assert {:ok, %ApiKey{} = api_key} = ApiKeys.refute_access(api_key, utc_now)
      assert api_key.expired_at == utc_now
    end

    test "when api_keys is already expired, returns the api_key without update its expiration date" do
      api_key_factory = insert!(:api_key) |> make_expired()
      utc_now = utc_now()

      assert {:ok, %ApiKey{} = api_key} = ApiKeys.refute_access(api_key_factory, utc_now)

      assert api_key.expired_at == api_key_factory.expired_at
    end
  end

  describe "touch" do
    test "when there is no usage_activity" do
      api_key = insert!(:api_key)

      assert {:ok, %ApiKeyUsage{used_at: used_at}} =
               ApiKeys.touch(api_key, %{"ip_address" => "127.0.0.0"})

      utc_now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
      assert DateTime.compare(used_at, utc_now) in [:eq, :lt]
    end

    test "when there is usage_activity" do
      api_key = insert!(:api_key)
      %{used_at: last_used_at} = insert!(:api_key_usage, api_key_id: api_key.id)

      assert {:ok, %ApiKeyUsage{used_at: new_last_used_at}} =
               ApiKeys.touch(api_key, %{"ip_address" => "ip_address"})

      refute DateTime.compare(last_used_at, new_last_used_at) in [:eq, :gt]

      utc_now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
      assert DateTime.compare(new_last_used_at, utc_now) in [:eq, :lt]
    end
  end

  describe "expired?/1" do
    test "when api_key has no expired_at, returns false" do
      api_key = insert!(:api_key, expired_at: nil)

      refute ApiKeys.expired?(api_key)
    end

    test "when expired_at is greater than now, returns false" do
      expired_at = utc_now() |> add(3600)
      api_key = insert!(:api_key, expired_at: expired_at)

      refute ApiKeys.expired?(api_key)
    end

    test "when expired_at is equal to now, returns false" do
      expired_at = utc_now()
      api_key = insert!(:api_key, expired_at: expired_at)

      assert ApiKeys.expired?(api_key)
    end

    test "when expired_at is less than now, returns false" do
      api_key = insert!(:api_key) |> make_expired()

      assert ApiKeys.expired?(api_key)
    end
  end

  describe "generate_secret_key/3" do
    test "generate secret returns a secret prefixed with the type and livemode prefix value" do
      generated_secret = ApiKeys.generate_secret_key("publishable", true)
      [type, _livemode, secret] = generated_secret |> String.split("_")
      assert type == "pk"
      assert String.length(secret) == 50

      generated_secret = ApiKeys.generate_secret_key("secret", true)
      [type, _livemode, _secret] = generated_secret |> String.split("_")
      assert type == "sk"

      generated_secret = ApiKeys.generate_secret_key("secret", true)
      [_type, livemode, _secret] = generated_secret |> String.split("_")
      assert livemode == "live"

      generated_secret = ApiKeys.generate_secret_key("secret", false)
      [_type, livemode, _secret] = generated_secret |> String.split("_")
      assert livemode == "test"
    end
  end
end
