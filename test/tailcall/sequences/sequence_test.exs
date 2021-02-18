defmodule Tailcall.Sequences.SequenceTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Sequences.Sequence

  @moduletag :sequences

  describe "create_changeset/2" do
    test "only permitted keys are casted" do
      sequence_params = params_for(:sequence, value: 100)

      changeset =
        Sequence.create_changeset(%Sequence{}, Map.merge(sequence_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()

      assert :livemode in changes_keys
      assert :name in changes_keys
      assert :value in changes_keys
      refute :new_key in changes_keys
    end

    test "when params are valid, returns an valid changeset" do
      sequence_params = params_for(:sequence)

      changeset = Sequence.create_changeset(%Sequence{}, sequence_params)

      assert changeset.valid?
      assert get_field(changeset, :livemode) == sequence_params.livemode
      assert get_field(changeset, :name) == sequence_params.name
      assert get_field(changeset, :value) == sequence_params.value
    end

    test "when required params are missing, returns an invalid changeset" do
      changeset = Sequence.create_changeset(%Sequence{}, %{value: nil})

      refute changeset.valid?
      assert %{livemode: ["can't be blank"]} = errors_on(changeset)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert %{value: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_changeset/2" do
    test "only permitted keys are casted" do
      sequence = insert!(:sequence)
      sequence_params = params_for(:sequence, value: 100)

      changeset =
        Sequence.update_changeset(sequence, Map.merge(sequence_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()
      refute :livemode in changes_keys
      refute :name in changes_keys
      assert :value in changes_keys
    end

    test "when params are valid, returns an valid changeset" do
      sequence = insert!(:sequence)

      changeset = Sequence.update_changeset(sequence, %{value: 100})

      assert changeset.valid?
      assert get_field(changeset, :value) == 100
    end

    test "when required params are missing, returns an invalid changeset" do
      sequence = insert!(:sequence)

      changeset = Sequence.update_changeset(sequence, %{value: nil})

      refute changeset.valid?
      assert %{value: ["can't be blank"]} = errors_on(changeset)
    end
  end
end
