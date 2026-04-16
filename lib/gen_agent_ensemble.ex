defmodule GenAgentEnsemble do
  @moduledoc """
  A session process that owns N `GenAgent` sub-agents under a strategy.

  Where `GenAgent` gives you one process per LLM session, `GenAgentEnsemble`
  gives you one process per *logical* session -- the single-agent case
  is `GenAgentEnsemble.Strategies.Solo`, multi-agent patterns like
  Supervisor or Pool are other strategies.

  ## Public API

      {:ok, pid} = GenAgentEnsemble.start_link(
        name: "research-1",
        strategy: GenAgentEnsemble.Strategies.Solo,
        opts: [agent: {"worker-a", MyAgent, backend: GenAgent.Backends.Mock}]
      )

      {:ok, token} = GenAgentEnsemble.tell("research-1", "hello")
      {:ok, :pending} = GenAgentEnsemble.poll("research-1", token)
      # ...later...
      {:ok, :completed, response} = GenAgentEnsemble.poll("research-1", token)

      {:ok, response} = GenAgentEnsemble.ask("research-1", "quick question", 30_000)

  See `GenAgentEnsemble.Strategy` for how to implement your own strategy.
  """

  defdelegate start_link(opts), to: GenAgentEnsemble.Server
  defdelegate tell(name, prompt), to: GenAgentEnsemble.Server
  defdelegate tell(name, prompt, opts), to: GenAgentEnsemble.Server
  defdelegate ask(name, prompt), to: GenAgentEnsemble.Server
  defdelegate ask(name, prompt, timeout), to: GenAgentEnsemble.Server
  defdelegate poll(name, token), to: GenAgentEnsemble.Server
  defdelegate inbox(name), to: GenAgentEnsemble.Server
  defdelegate notify(name, event), to: GenAgentEnsemble.Server
  defdelegate status(name), to: GenAgentEnsemble.Server
  defdelegate stop(name), to: GenAgentEnsemble.Server

  @doc """
  List the names of all running ensembles, sorted.

      iex> GenAgentEnsemble.list()
      ["qa-pool", "solo"]
  """
  @spec list() :: [String.t()]
  def list do
    GenAgentEnsemble.Registry
    |> Registry.select([{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.sort()
  end

  @doc """
  Enter a line-oriented conversational REPL over a running ensemble.

  See `GenAgentEnsemble.Chat` for details and slash commands.
  """
  defdelegate chat(name), to: GenAgentEnsemble.Chat, as: :start
end
