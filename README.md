# gen_agent_ensemble

Multi-agent orchestration strategies for
[GenAgent](https://hex.pm/packages/gen_agent). Where `GenAgent`
gives you one process per LLM session, `gen_agent_ensemble` gives
you one process per *logical* session that owns N sub-agents under
a strategy. Single-agent is the degenerate `Solo` case.

This library is both:

- **A library** consumed by applications (MCP servers, LiveView
  apps, scripts) that need multi-agent orchestration.
- **A platform** for Elixir power users. Declare ensembles in
  `config/config.exs`, run `iex -S mix`, and your ensembles are
  live as named processes you can drive directly.

## Strategies (shipped)

| Strategy      | Topology                                 | Module                                      |
|---------------|------------------------------------------|---------------------------------------------|
| Solo          | One agent, passthrough                   | `GenAgentEnsemble.Strategies.Solo`          |
| Supervisor    | Coordinator + dynamic worker fan-out     | `GenAgentEnsemble.Strategies.Supervisor`    |
| Pool          | N reusable workers, FIFO queue           | `GenAgentEnsemble.Strategies.Pool`          |
| Pipeline      | Linear stage chain                       | `GenAgentEnsemble.Strategies.Pipeline`      |

Planned: Switchboard, Debate, Consensus.

See the [gen_agent pattern guides](https://hexdocs.pm/gen_agent)
for the shape of each strategy and how to reason about their
behaviour.

## Install

```elixir
def deps do
  [
    {:gen_agent_ensemble, "~> 0.1"},
    # Plus at least one backend:
    {:gen_agent_anthropic, "~> 0.1"},
    # and/or:
    {:gen_agent_claude, "~> 0.1"},
    {:gen_agent_openai, "~> 0.1"},
    {:gen_agent_codex, "~> 0.1"}
  ]
end
```

## Quickstart (config-driven)

Edit `config/config.exs` in your app:

```elixir
import Config

config :gen_agent_ensemble,
  ensembles: [
    [
      name: "solo",
      strategy: GenAgentEnsemble.Strategies.Solo,
      opts: [
        agent:
          {"w", GenAgentEnsemble.Agents.Simple,
           backend: GenAgent.Backends.Anthropic,
           system: "You are a pragmatic Elixir reviewer.",
           model: "claude-sonnet-4-6"}
      ]
    ]
  ]
```

Start iex:

```sh
iex -S mix
```

Your ensemble is live as `"solo"`:

```elixir
iex> {:ok, resp} = GenAgentEnsemble.ask("solo", "What's wrong with `Enum.map(list, &(&1 + 1))`?")
iex> IO.puts(resp.text)
```

Async mode with a Pool (also declared in config):

```elixir
iex> {:ok, t1} = GenAgentEnsemble.tell("qa-pool", "question one")
iex> {:ok, t2} = GenAgentEnsemble.tell("qa-pool", "question two")
iex> GenAgentEnsemble.status("qa-pool")
iex> {:ok, done} = GenAgentEnsemble.inbox("qa-pool")   # drains completed
```

## Public API

All functions are addressed by session name (the `:name` you put
in config).

| Function                                | Purpose                                            |
|-----------------------------------------|----------------------------------------------------|
| `GenAgentEnsemble.ask(name, prompt)`    | Synchronous single-turn. Blocks until reply.       |
| `GenAgentEnsemble.tell(name, prompt)`   | Async. Returns a `token` you poll or drain later.  |
| `GenAgentEnsemble.poll(name, token)`    | Non-blocking check on a single token.              |
| `GenAgentEnsemble.inbox(name)`          | Drain all completed tokens since last call.        |
| `GenAgentEnsemble.notify(name, event)`  | Send an event to the strategy (cast).              |
| `GenAgentEnsemble.status(name)`         | Inspect strategy phase, queue depth, etc.          |
| `GenAgentEnsemble.stop(name)`           | Stop an ensemble cleanly.                          |
| `GenAgentEnsemble.start_link(opts)`     | Start an ad-hoc ensemble imperatively (same shape  |
|                                         | as a config entry).                                |

## Ad-hoc ensembles from iex

You don't have to use config. Any ensemble can be started
imperatively with the same opts shape:

```elixir
iex> GenAgentEnsemble.start_link(
...>   name: "scratch",
...>   strategy: GenAgentEnsemble.Strategies.Solo,
...>   opts: [
...>     agent: {"w", GenAgentEnsemble.Agents.Simple,
...>             backend: GenAgent.Backends.Mock,
...>             scripts: [{"hello", ["hi!"]}]}
...>   ]
...> )
```

This is the natural way to prototype: try a config inline, iterate,
then promote to `config/config.exs` when you're happy with it.

## Secrets and `config/runtime.exs`

API keys and other secrets don't belong in `config/config.exs`
(compile-time evaluated, checked into git). Use
`config/runtime.exs` or environment variables that the backend
reads directly.

For Anthropic:

```sh
export ANTHROPIC_API_KEY=...
iex -S mix
```

## Built-in `Simple` agent

`GenAgentEnsemble.Agents.Simple` is a reusable one-turn callback
module. Accepts any backend options (`:system`, `:system_prompt`,
`:model`, `:cwd`, etc.) and forwards them to the backend. Use it
for iex experimentation and as the worker for simple ensembles.

For real projects you'll typically write your own callback module
with richer state and prompt-engineered behaviour -- Simple is the
shortest path to "working ensemble in 10 lines of config."

## Development

Running from the monorepo layout (this repo checked out as a
sibling of `gen_agent/`, `gen_agent_claude/`, etc.):

```sh
mix deps.get
mix test
```

`mix.exs` auto-detects the monorepo layout and uses path deps for
`gen_agent` when the sibling directory exists, falling back to hex
otherwise. This means a bare clone also just works.

## Status

Pre-1.0. The op vocabulary
(`:start | :stop | :dispatch | :reply | :reply_error | :forward | :halt`)
and public API are stabilizing; breaking changes will bump the
minor version. See `CHANGELOG.md` once it exists.
