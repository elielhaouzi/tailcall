defmodule Tailcall.Sequences do
  import Ecto.Query, only: [where: 2]

  alias Tailcall.Repo
  alias Tailcall.Sequences.Sequence

  @spec create_sequence(binary, boolean) :: {:ok, Sequence.t()} | {:error, Ecto.Changeset.t()}
  def create_sequence(name, livemode?) when is_binary(name) and is_boolean(livemode?) do
    %Sequence{}
    |> Sequence.create_changeset(%{name: name, livemode: livemode?})
    |> Repo.insert()
  end

  @spec next_value!(binary, boolean) :: integer
  def next_value!(name, livemode?) when is_binary(name) and is_boolean(livemode?) do
    %{rows: [[nextval]]} =
      Repo.query!("SELECT nextval_gapless_sequence($1, $2);", [name, livemode?])

    nextval
  end

  @spec current_value!(binary, boolean) :: integer
  def current_value!(name, livemode?) when is_binary(name) and is_boolean(livemode?) do
    %Sequence{value: value} =
      Sequence
      |> where(name: ^name, livemode: ^livemode?)
      |> Repo.one!()

    value
  end

  @spec sequence_exists?(binary, boolean) :: boolean
  def sequence_exists?(name, livemode?) when is_binary(name) and is_boolean(livemode?) do
    Sequence
    |> where(name: ^name, livemode: ^livemode?)
    |> Repo.exists?()
  end
end
