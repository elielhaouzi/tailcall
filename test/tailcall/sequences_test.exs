defmodule Tailcall.SequencesTest do
  use ExUnit.Case, async: false
  use Tailcall.DataCase

  alias Tailcall.Sequences
  alias Tailcall.Sequences.Sequence

  @moduletag :sequences

  describe "create_sequence/2" do
    test "when params are valid, returns the sequence" do
      sequence_params = params_for(:sequence)

      assert {:ok, %Sequence{}} =
               Sequences.create_sequence(sequence_params.name, sequence_params.livemode)

      assert {:ok, %Sequence{}} =
               Sequences.create_sequence(sequence_params.name, !sequence_params.livemode)
    end

    test "when sequence already exists, returns an error tuple with an invalid changeset" do
      sequence = insert!(:sequence)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Sequences.create_sequence(sequence.name, sequence.livemode)

      refute changeset.valid?
      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "next_value/2" do
    test "when the sequence exists, returns the sequence's next value" do
      sequence = insert!(:sequence)

      assert Sequences.next_value!(sequence.name, sequence.livemode) == 1
      assert Sequences.next_value!(sequence.name, sequence.livemode) == 2
    end

    test "with an non existing sequence, returns nil" do
      assert is_nil(Sequences.next_value!("name", false))
    end
  end

  describe "current_value/2" do
    test "when the sequence exists, returns the sequence's current value" do
      sequence = insert!(:sequence)

      assert Sequences.current_value!(sequence.name, sequence.livemode) == 0
      assert Sequences.current_value!(sequence.name, sequence.livemode) == 0
    end

    test "with an non existing sequence, raises Ecto.NoResultsError" do
      assert_raise Ecto.NoResultsError, fn ->
        Sequences.current_value!("name", false)
      end
    end
  end

  describe "sequence_exists?/2" do
    test "when the sequence exists, returns true" do
      sequence = insert!(:sequence)

      assert Sequences.sequence_exists?(sequence.name, sequence.livemode)
    end

    test "with an non existing sequence, returns false" do
      refute Sequences.sequence_exists?("name", false)
    end
  end
end
