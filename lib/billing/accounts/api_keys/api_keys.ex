defmodule Billing.Accounts.ApiKeys do
  import Ecto.Query, only: [order_by: 2]

  alias Ecto.Multi
  alias Billing.Repo
  alias Billing.Accounts.ApiKeys.{ApiKey, ApiKeyQueryable, ApiKeyUsage}

  @key_default_length 50

  @spec list_api_keys(keyword) :: [ApiKey.t()]
  def list_api_keys(opts \\ []) do
    opts
    |> api_key_queryable()
    |> order_by(asc: :created_at)
    |> Repo.all()
  end

  @spec create_api_key(map) :: {:ok, ApiKey.t()} | {:error, Ecto.Changeset.t()}
  def create_api_key(attrs) when is_map(attrs) do
    %ApiKey{}
    |> ApiKey.create_changeset(attrs)
    |> Repo.insert()
  end

  @spec get_api_key(binary, keyword()) :: ApiKey.t() | nil
  def get_api_key(id, opts \\ []) when is_binary(id) do
    opts
    |> Keyword.put(:filters, id: id)
    |> api_key_queryable()
    |> Repo.one()
  end

  @spec get_api_key_by([{:secret, binary}], keyword) :: ApiKey.t() | nil
  def get_api_key_by([secret: secret], opts \\ []) when is_binary(secret) do
    opts
    |> Keyword.put(:filters, secret: secret)
    |> api_key_queryable()
    |> Repo.one()
  end

  @spec roll_api_key(ApiKey.t(), DateTime.t()) :: {:ok, ApiKey.t()} | {:error, Ecto.Changeset.t()}
  def roll_api_key(%ApiKey{} = api_key, %DateTime{} = expires_at \\ DateTime.utc_now()) do
    Multi.new()
    |> Multi.run(:old_api_key, fn _, %{} ->
      refute_access(api_key, expires_at)
    end)
    |> Multi.run(:api_key, fn _, %{old_api_key: old_api_key} ->
      create_api_key(%{
        user_id: old_api_key.user_id,
        created_at: DateTime.utc_now(),
        livemode: old_api_key.livemode,
        secret: generate_secret_key(old_api_key.type, old_api_key.livemode),
        type: old_api_key.type
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{api_key: %ApiKey{} = api_key}} ->
        {:ok, api_key}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @spec refute_access(ApiKey.t(), DateTime.t()) ::
          {:ok, ApiKey.t()} | {:error, Ecto.Changeset.t()}
  def refute_access(%ApiKey{} = api_key, %DateTime{} = datetime) do
    refute_access(api_key, datetime, expired?(api_key))
  end

  defp refute_access(%ApiKey{} = api_key, _, true = _expired?), do: {:ok, api_key}

  defp refute_access(%ApiKey{} = api_key, %DateTime{} = datetime, false = _expired?) do
    api_key
    |> ApiKey.remove_changeset(%{expired_at: datetime})
    |> Repo.update()
  end

  @spec touch(ApiKey.t(), map()) :: {:ok, ApiKeyUsage.t()} | {:error, Ecto.Changeset.t()}
  def touch(%ApiKey{id: api_key_id}, attrs) when is_map(attrs) do
    attrs =
      attrs
      |> Map.put("api_key_id", api_key_id)
      |> Map.put("used_at", DateTime.utc_now())
      |> Map.put("request_id", Logger.metadata()[:request_id])

    %ApiKeyUsage{}
    |> ApiKeyUsage.changeset(attrs)
    |> Repo.insert()
  end

  @spec expired?(ApiKey.t()) :: boolean
  def expired?(%ApiKey{expired_at: nil}), do: false

  def expired?(%ApiKey{expired_at: expired_at}) do
    DateTime.compare(expired_at, DateTime.utc_now()) in [:lt, :eq]
  end

  @spec generate_secret_key(binary, boolean, pos_integer) :: binary
  def generate_secret_key(type, livemode?, length \\ @key_default_length)
      when type in ["publishable", "secret"] and is_boolean(livemode?) and is_integer(length) and
             length > 0 do
    type_prefixes = %{"publishable" => "pk", "secret" => "sk"}
    livemode_prefixes = %{true: "live", false: "test"}
    prefix_separator = "_"

    replacement =
      [?0..?9, ?a..?z, ?A..?Z]
      |> Enum.flat_map(&Enum.to_list/1)
      |> Enum.random()
      |> List.wrap()
      |> to_string()

    secret =
      :crypto.strong_rand_bytes(length)
      |> Base.url_encode64(padding: false)
      |> String.replace(prefix_separator, replacement)
      |> binary_part(0, length)

    "#{type_prefixes[type]}#{prefix_separator}#{livemode_prefixes[livemode?]}#{prefix_separator}#{
      secret
    }"
  end

  defp api_key_queryable(opts) when is_list(opts) do
    filters = Keyword.get(opts, :filters, [])
    includes = Keyword.get(opts, :includes, [])

    ApiKeyQueryable.queryable()
    |> ApiKeyQueryable.filter(filters)
    |> ApiKeyQueryable.with_preloads(includes)
  end
end
