defmodule Tailcall.Billing.Invoices.Workers.AutoAdvanceWorker do
  use Oban.Worker,
    queue: :invoices,
    unique: [period: :infinity, fields: [:queue, :args, :worker], keys: [:id]]

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: :ok
  def perform(%Oban.Job{args: %{"id" => _id} = _args}) do
    :ok
  end
end
