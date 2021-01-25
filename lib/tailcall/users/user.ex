defmodule Tailcall.Users.User do
  use Ecto.Schema

  import Ecto.Changeset,
    only: [
      assoc_constraint: 2,
      cast: 3,
      put_assoc: 3,
      unique_constraint: 2,
      validate_required: 2
    ]

  alias Annacl.Performers.Performer

  @type t :: %__MODULE__{
          created_at: DateTime.t(),
          email: binary,
          deleted_at: DateTime.t() | nil,
          id: binary,
          inserted_at: DateTime.t(),
          name: binary | nil,
          object: binary,
          performer: Performer.t(),
          performer_id: integer,
          updated_at: DateTime.t()
        }

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "usr", autogenerate: true}
  schema "users" do
    field(:object, :string, default: "user")

    belongs_to(:performer, Performer)

    field(:created_at, :utc_datetime)
    field(:email, :string)
    field(:name, :string)

    field(:deleted_at, :utc_datetime)
    timestamps(type: :utc_datetime)
  end

  @spec create_changeset(User.t(), map) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = user, attrs) when is_map(attrs) do
    user
    |> cast(attrs, [:created_at, :email, :name])
    |> put_assoc(:performer, %{})
    |> validate_required([:created_at, :email])
    |> unique_constraint(:email)
    |> assoc_constraint(:performer)
  end

  @spec update_changeset(User.t(), map) :: Ecto.Changeset.t()
  def update_changeset(%__MODULE__{} = user, attrs) when is_map(attrs) do
    user
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end

  @spec delete_changeset(User.t(), map) :: Ecto.Changeset.t()
  def delete_changeset(%__MODULE__{} = user, attrs) when is_map(attrs) do
    user
    |> cast(attrs, [:deleted_at])
    |> validate_required([:deleted_at])
    |> AntlUtilsEcto.Changeset.validate_datetime_gte(:deleted_at, :created_at)
  end
end
