defmodule Tailcall.Audit.Events.EventQueryable do
  use AntlUtilsEcto.Queryable,
    base_schema: Tailcall.Audit.Events.Event
end
