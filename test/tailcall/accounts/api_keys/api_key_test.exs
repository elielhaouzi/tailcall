defmodule Tailcall.Accounts.ApiKeys.ApiKeyTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Accounts.ApiKeys
  alias Tailcall.Accounts.ApiKeys.ApiKey

  describe "create_changeset/2" do
    test "only permitted_keys are casted" do
      api_key_params = build(:api_key, livemode: true) |> make_expired() |> params_for()

      changeset =
        ApiKey.create_changeset(%ApiKey{}, Map.merge(api_key_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()

      assert :user_id in changes_keys
      assert :created_at in changes_keys
      assert :expired_at in changes_keys
      assert :livemode in changes_keys
      assert :secret in changes_keys
      assert :type in changes_keys

      refute :new_key in changes_keys
    end

    test "when required params are missing, returns an invalid changeset" do
      changeset = ApiKey.create_changeset(%ApiKey{}, %{})

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
      assert %{created_at: ["can't be blank"]} = errors_on(changeset)
      assert %{livemode: ["can't be blank"]} = errors_on(changeset)
      assert %{secret: ["can't be blank"]} = errors_on(changeset)
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "when secret is less than @key_min_length, returns an invalid changeset" do
      api_key_params = params_for(:api_key, secret: "123")
      changeset = ApiKey.create_changeset(%ApiKey{}, api_key_params)

      refute changeset.valid?
      assert %{secret: ["should be at least 35 character(s)"]} = errors_on(changeset)
    end

    test "when secret is more than @key_max_length, returns an invalid changeset" do
      api_key_params =
        params_for(:api_key, secret: ApiKeys.generate_secret_key("secret", false, 255))

      changeset = ApiKey.create_changeset(%ApiKey{}, api_key_params)

      refute changeset.valid?
      assert %{secret: ["should be at most 245 character(s)"]} = errors_on(changeset)
    end

    test "when params are valid, return a valid changeset" do
      api_key_params = build(:api_key) |> make_expired() |> params_for()

      changeset = ApiKey.create_changeset(%ApiKey{}, api_key_params)

      assert changeset.valid?
      assert get_field(changeset, :user_id) == api_key_params.user_id
      assert get_field(changeset, :created_at) == api_key_params.created_at
      assert get_field(changeset, :expired_at) == api_key_params.expired_at
      assert get_field(changeset, :livemode) == api_key_params.livemode
      assert get_field(changeset, :secret) == api_key_params.secret
      assert get_field(changeset, :type) == api_key_params.type
    end
  end

  describe "remove_changeset/2" do
    test "only permitted_keys are casted" do
      api_key = insert!(:api_key)

      api_key_params = build(:api_key) |> make_expired() |> params_for()

      changeset = ApiKey.remove_changeset(api_key, Map.merge(api_key_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()

      refute :user_id in changes_keys
      refute :created_at in changes_keys
      assert :expired_at in changes_keys
      refute :livemode in changes_keys
      refute :secret in changes_keys
      refute :type in changes_keys
      refute :new_key in changes_keys
    end

    test "when params are valid, return a valid changeset" do
      api_key = insert!(:api_key)

      api_key_params = build(:api_key) |> make_expired() |> params_for()

      changeset = ApiKey.remove_changeset(api_key, api_key_params)

      assert changeset.valid?
      assert get_field(changeset, :expired_at) == api_key_params.expired_at
    end

    test "when expired_at is before the created_at, returns a changeset error" do
      api_key = insert!(:api_key)

      api_key_params = build(:api_key, expired_at: utc_now() |> add(-3600)) |> params_for()

      changeset = ApiKey.remove_changeset(api_key, api_key_params)

      refute changeset.valid?

      assert %{expired_at: ["should be after or equal to created_at"]} ==
               errors_on(changeset)
    end

    test "when expired_at is after the max expiration time, returns a changeset error" do
      api_key = insert!(:api_key)
      max_expiration_time = utc_now() |> add(7 * 24 * 3600 + 100)

      over_max_expiration_time = max_expiration_time |> add(100)

      api_key_params = build(:api_key, expired_at: over_max_expiration_time) |> params_for()

      changeset = ApiKey.remove_changeset(api_key, api_key_params)

      refute changeset.valid?

      assert %{expired_at: ["should be before or equal to #{max_expiration_time}"]} ==
               errors_on(changeset)
    end
  end
end
