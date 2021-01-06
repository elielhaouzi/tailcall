defmodule Billing.Accounts.Users.UserQueryable do
  use AntlUtilsEcto.Queryable,
    base_schema: Billing.Accounts.Users.User
end
