defmodule Billing.Accounts.Users.User do
  use Ecto.Schema

  import Ecto.Changeset,
    only: [
      assoc_constraint: 2,
      cast: 3,
      cast_assoc: 3,
      unique_constraint: 2,
      validate_required: 2
    ]

  alias Annacl.Performers.Performer

  @type t :: %__MODULE__{
          email: binary,
          id: binary,
          inserted_at: DateTime.t(),
          name: binary,
          object: binary,
          performer_id: integer,
          updated_at: DateTime.t()
        }

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "usr", autogenerate: true}
  schema "users" do
    field(:object, :string)

    belongs_to(:performer, Performer)

    field(:email, :string)
    field(:name, :string)

    timestamps()
  end

  @spec create_changeset(User.t(), map) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = user, attrs) when is_map(attrs) do
    attrs = attrs |> Map.put(:performer, %{})

    user
    |> cast(attrs, [:email, :name])
    |> cast_assoc(:performer, required: true)
    |> validate_required([:email])
    |> unique_constraint(:email)
    |> assoc_constraint(:performer)
  end

  @spec update_changeset(User.t(), map) :: Ecto.Changeset.t()
  def update_changeset(%__MODULE__{} = user, attrs) when is_map(attrs) do
    user
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
