defmodule Tailcall.Repo.Migrations.CreateSequencesTable do
  use Ecto.Migration

  def change do
    create table(:sequences, primary: false) do
      add(:livemode, :boolean, null: false)
      add(:name, :string, null: false)
      add(:value, :bigint, null: false, default: 0)
    end

    create(unique_index(:sequences, [:name, :livemode]))
    create(index(:sequences, [:value]))

    execute("""
      create or replace function nextval_gapless_sequence(in_sequence_name text, in_livemode bool)
      returns bigint
      language plpgsql
      as
      $$
      declare
        next_value bigint := 1;
      begin
        update sequences
        set value = value + 1
        where name = in_sequence_name and livemode = in_livemode
        returning value into next_value;

        return next_value;
      end;
      $$;
    """)
  end
end
