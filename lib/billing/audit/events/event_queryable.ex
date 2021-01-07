defmodule Billing.Audit.Events.EventQueryable do
  use AntlUtilsEcto.Queryable,
    base_schema: Billing.Audit.Events.Event,
    sortable_fields: [:id]
end
