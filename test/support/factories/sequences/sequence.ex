defmodule Tailcall.Factory.Sequences.Sequence do
  alias Tailcall.Sequences.Sequence

  defmacro __using__(_opts) do
    quote do
      def build(:sequence, attrs) do
        %Sequence{
          livemode: false,
          name: "name_#{System.unique_integer([:positive])}"
        }
        |> struct!(attrs)
      end
    end
  end
end
