defmodule Tailcall.Core.Customers.InvoiceSettingsTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Core.Customers.InvoiceSettings
  alias Tailcall.Core.Customers.InvoiceSettings.CustomField

  describe "changeset/2" do
    test "only permitted_keys are casted" do
      invoice_settings_params = build(:customer_invoice_settings) |> Map.from_struct()

      changeset =
        InvoiceSettings.changeset(
          %InvoiceSettings{},
          Map.merge(invoice_settings_params, %{new_key: "value"})
        )

      changes_keys = changeset.changes |> Map.keys()

      assert :custom_fields in changes_keys
      assert :footer in changes_keys
      refute :new_key in changes_keys
    end

    test "when all params are valid, returns an valid changeset" do
      %{custom_fields: [custom_field]} =
        invoice_settings_params = build(:customer_invoice_settings) |> Map.from_struct()

      changeset = InvoiceSettings.changeset(%InvoiceSettings{}, invoice_settings_params)

      assert changeset.valid?

      assert [%CustomField{name: custom_field.name, value: custom_field.value}] ==
               get_field(changeset, :custom_fields)

      assert get_field(changeset, :footer) == invoice_settings_params.footer
    end
  end
end
