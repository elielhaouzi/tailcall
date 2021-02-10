defmodule Tailcall.Core.Customers.InvoiceSettings.CustomFieldTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Core.Customers.InvoiceSettings.CustomField

  describe "changeset/2" do
    test "only permitted_keys are casted" do
      custom_field_params = build(:customer_invoice_settings_custom_field) |> Map.from_struct()

      changeset =
        CustomField.changeset(
          %CustomField{},
          Map.merge(custom_field_params, %{new_key: "value"})
        )

      changes_keys = changeset.changes |> Map.keys()

      assert :name in changes_keys
      assert :value in changes_keys
      refute :new_key in changes_keys
    end

    test "when all params are valid, returns an valid changeset" do
      custom_field_params = build(:customer_invoice_settings_custom_field) |> Map.from_struct()

      changeset = CustomField.changeset(%CustomField{}, custom_field_params)

      assert changeset.valid?
      assert get_field(changeset, :name) == custom_field_params.name
      assert get_field(changeset, :value) == custom_field_params.value
    end

    test "when required params are missing, returns an invalid changeset" do
      changeset = CustomField.changeset(%CustomField{}, %{})

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert %{value: ["can't be blank"]} = errors_on(changeset)
    end
  end
end
