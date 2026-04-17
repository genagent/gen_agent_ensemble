import Config

# Ensembles declared here are started automatically when the
# `:gen_agent_ensemble` app boots, and are addressable by name via the
# public API (`GenAgentEnsemble.tell/2`, `ask/2`, `poll/2`, `inbox/1`,
# `status/1`, `stop/1`) from any iex session started with
# `iex -S mix`.
#
# Each entry is the same keyword list you would pass to
# `GenAgentEnsemble.start_link/1`: `:name`, `:strategy`, `:opts`.
#
# Secrets (API keys, tokens) do NOT belong here -- use
# `config/runtime.exs` for those, where `System.get_env/1` is
# available at runtime.
#
# Examples (uncomment and edit to taste):

# config :gen_agent_ensemble,
#   ensembles: [
#     # Zero-setup demo. Every prompt is echoed back with an
#     # "echo: " prefix via GenAgentEnsemble.Backends.Echo. No API
#     # keys, no subprocess. Useful for trying chat/1 or prototyping
#     # pipelines before wiring a real backend.
#     [
#       name: "echo",
#       strategy: GenAgentEnsemble.Strategies.Solo,
#       opts: [
#         agent:
#           {"w", GenAgentEnsemble.Agents.Simple,
#            backend: GenAgentEnsemble.Backends.Echo,
#            delay_ms: 300}
#       ]
#     ],
#
#     # Single-agent passthrough. The simplest useful ensemble --
#     # one named process, one backend session behind it.
#     [
#       name: "solo",
#       strategy: GenAgentEnsemble.Strategies.Solo,
#       opts: [
#         agent:
#           {"w", GenAgentEnsemble.Agents.Simple,
#            backend: GenAgent.Backends.Anthropic,
#            system: "You are a pragmatic Elixir reviewer.",
#            model: "claude-sonnet-4-6"}
#       ]
#     ],
#
#     # Fixed-size worker pool. `tell` fans out across workers in
#     # parallel; drain completed tokens with `inbox/1`.
#     [
#       name: "qa-pool",
#       strategy: GenAgentEnsemble.Strategies.Pool,
#       opts: [
#         worker_count: 3,
#         worker_template:
#           {"qa", GenAgentEnsemble.Agents.Simple,
#            backend: GenAgent.Backends.Anthropic,
#            system: "Answer tersely. One paragraph max.",
#            model: "claude-sonnet-4-6"}
#       ]
#     ],
#
#     # Named fleet, caller-routed. Every tell/ask must specify
#     # `opts[:agent]`; the addressed agent answers. Use it for
#     # "specialist team" shapes.
#     [
#       name: "reviewers",
#       strategy: GenAgentEnsemble.Strategies.Switchboard,
#       opts: [
#         agents: [
#           {"alice", GenAgentEnsemble.Agents.Simple,
#             backend: GenAgent.Backends.Anthropic,
#             system: "You review API design."},
#           {"bob", GenAgentEnsemble.Agents.Simple,
#             backend: GenAgent.Backends.Anthropic,
#             system: "You review performance."}
#         ]
#       ]
#     ],
#
#     # Linear N-stage chain. Each stage's response text becomes the
#     # next stage's prompt. Last stage's response is the reply.
#     [
#       name: "brainstorm",
#       strategy: GenAgentEnsemble.Strategies.Pipeline,
#       opts: [
#         stages: [
#           {"ideator", GenAgentEnsemble.Agents.Simple,
#             backend: GenAgent.Backends.Anthropic,
#             system: "List 5 ideas for the given topic."},
#           {"editor", GenAgentEnsemble.Agents.Simple,
#             backend: GenAgent.Backends.Anthropic,
#             system: "Pick the best idea from this list and explain why."},
#           {"headliner", GenAgentEnsemble.Agents.Simple,
#             backend: GenAgent.Backends.Anthropic,
#             system: "Write a single punchy one-line headline."}
#         ]
#       ]
#     ]
#   ]

import_config "#{config_env()}.exs"
