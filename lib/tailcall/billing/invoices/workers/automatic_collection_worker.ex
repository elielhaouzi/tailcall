defmodule Tailcall.Billing.Invoices.Workers.AutomaticCollectionWorker do
  use Oban.Worker,
    queue: :invoices,
    unique: [period: :infinity, fields: [:queue, :args, :worker], keys: [:id]]

  alias Tailcall.Billing.Invoices
  alias Tailcall.Billing.Invoices.Invoice

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def perform(%Oban.Job{args: %{"id" => id} = _args}) do
    draft_status = Invoice.statuses().draft

    id
    |> Invoices.get_invoice!(includes: [:account])
    |> case do
      %Invoice{status: ^draft_status} = invoice -> Invoices.finalize_invoice(invoice)
      %Invoice{} = invoice -> {:ok, invoice}
    end
  end
end
