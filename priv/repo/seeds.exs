# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Tailcall.Repo.insert!(%Tailcall.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
{:ok, _} = Annacl.create_role(Annacl.superadmin_role_name())

{:ok, _} = Annacl.create_role("user_role_admin")
{:ok, _} = Annacl.create_role("user_role_developer")
{:ok, _} = Annacl.create_role("user_role_operator")
{:ok, _} = Annacl.create_role("user_role_support")
{:ok, _} = Annacl.create_role("user_role_read_only")
