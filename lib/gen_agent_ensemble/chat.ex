defmodule GenAgentEnsemble.Chat do
  @moduledoc """
  A line-oriented conversational REPL over a running ensemble.

  Intended for iex use:

      iex> GenAgentEnsemble.chat("solo")
      solo> what's wrong with `Enum.map(list, &(&1 + 1))`?
      ⋯ thinking
      solo: Nothing syntactically...
      solo> /exit
      iex>

  Not a TUI -- no alternate screen buffer, no cursor positioning, no
  keystroke grabbing. Just a readline-style prompt/response loop with
  ANSI styling and a handful of slash commands. `/exit` returns to
  iex with full programmatic power.

  ## Slash commands

    * `/status`          -- show strategy status for the current ensemble
    * `/history`         -- dump turns taken in this chat session
    * `/switch <name>`   -- switch to a different running ensemble
    * `/list`            -- list all running ensembles
    * `/clear`           -- clear the terminal
    * `/help`            -- show help
    * `/exit` or `/quit` -- leave chat
  """

  @ask_timeout 120_000

  def start(name) when is_binary(name) do
    case ensure_exists(name) do
      :ok ->
        banner()
        loop(%{name: name, history: []})
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ensure_exists(name) do
    try do
      _ = GenAgentEnsemble.status(name)
      :ok
    catch
      :exit, _ ->
        IO.puts(IO.ANSI.format([:red, "ensemble not found: ", :reset, name]))

        case list_ensembles() do
          [] ->
            IO.puts(IO.ANSI.format([:faint, "  (no ensembles running)", :reset]))

          available ->
            IO.puts(
              IO.ANSI.format([
                :faint,
                "  available: ",
                Enum.join(available, ", "),
                :reset
              ])
            )
        end

        {:error, :not_found}
    end
  end

  defp banner do
    IO.puts(
      IO.ANSI.format([
        :faint,
        "gen_agent_ensemble chat -- /help for commands, /exit to leave",
        :reset
      ])
    )
  end

  defp loop(state) do
    prompt = IO.ANSI.format([:cyan, state.name, "> ", :reset]) |> IO.iodata_to_binary()

    case IO.gets(prompt) do
      :eof ->
        IO.puts("")
        bye()

      {:error, reason} ->
        IO.puts(IO.ANSI.format([:red, "input error: ", :reset, inspect(reason)]))
        bye()

      line when is_binary(line) ->
        dispatch(String.trim(line), state)
    end
  end

  defp dispatch("", state), do: loop(state)

  defp dispatch("/" <> _ = line, state), do: handle_command(line, state)

  defp dispatch(line, state), do: loop(handle_prompt(line, state))

  defp handle_prompt(prompt, state) do
    IO.write(IO.ANSI.format([:faint, "⋯ thinking", :reset]))

    result =
      try do
        GenAgentEnsemble.ask(state.name, prompt, @ask_timeout)
      catch
        :exit, reason -> {:error, {:exit, reason}}
      end

    clear_line()

    case result do
      {:ok, response} ->
        text = response_text(response)
        print_response(state.name, text, response)

        %{
          state
          | history: state.history ++ [{:user, prompt}, {:assistant, text}]
        }

      {:error, reason} ->
        IO.puts(IO.ANSI.format([:red, "error: ", :reset, inspect(reason)]))
        state
    end
  end

  defp print_response(name, text, response) do
    IO.puts(IO.ANSI.format([:green, name, ":", :reset, " ", text]))

    meta = format_meta(response)

    if meta != "" do
      IO.puts(IO.ANSI.format([:faint, "  ", meta, :reset]))
    end
  end

  defp format_meta(%{duration_ms: ms, usage: usage}) when is_integer(ms) do
    base = "#{ms}ms"

    case usage do
      %{input_tokens: i, output_tokens: o} -> "#{base} · #{i} in / #{o} out"
      _ -> base
    end
  end

  defp format_meta(_), do: ""

  defp response_text(%{text: text}) when is_binary(text), do: text
  defp response_text(text) when is_binary(text), do: text
  defp response_text(other), do: inspect(other)

  # --- commands ---

  defp handle_command(cmd, _state) when cmd in ["/exit", "/quit"], do: bye()

  defp handle_command("/help", state) do
    IO.puts(
      IO.ANSI.format([
        :faint,
        """

          /status             show strategy status
          /history            dump turns taken in this chat session
          /switch <name>      switch to a different running ensemble
          /list               list running ensembles
          /clear              clear terminal
          /help               this help
          /exit, /quit        leave chat
        """,
        :reset
      ])
    )

    loop(state)
  end

  defp handle_command("/status", state) do
    status = GenAgentEnsemble.status(state.name)
    IO.puts(IO.ANSI.format([:faint, format_status(status), :reset]))
    loop(state)
  end

  defp handle_command("/history", state) do
    if state.history == [] do
      IO.puts(IO.ANSI.format([:faint, "(no turns yet)", :reset]))
    else
      for {role, text} <- state.history do
        case role do
          :user ->
            IO.puts(IO.ANSI.format([:cyan, state.name, "> ", :reset, text]))

          :assistant ->
            IO.puts(IO.ANSI.format([:green, state.name, ": ", :reset, text]))
        end
      end
    end

    loop(state)
  end

  defp handle_command("/list", state) do
    case list_ensembles() do
      [] ->
        IO.puts(IO.ANSI.format([:faint, "(no running ensembles)", :reset]))

      names ->
        for n <- names do
          marker = if n == state.name, do: "* ", else: "  "
          IO.puts(IO.ANSI.format([:faint, marker, n, :reset]))
        end
    end

    loop(state)
  end

  defp handle_command("/clear", state) do
    IO.write("\e[2J\e[H")
    loop(state)
  end

  defp handle_command("/switch " <> rest, state) do
    new_name = String.trim(rest)

    case ensure_exists(new_name) do
      :ok ->
        IO.puts(IO.ANSI.format([:faint, "switched to ", new_name, :reset]))
        loop(%{state | name: new_name, history: []})

      {:error, _} ->
        loop(state)
    end
  end

  defp handle_command(other, state) do
    IO.puts(IO.ANSI.format([:red, "unknown command: ", :reset, other, " -- try /help"]))

    loop(state)
  end

  defp bye do
    IO.puts(IO.ANSI.format([:faint, "bye", :reset]))
    :ok
  end

  # --- helpers ---

  defp clear_line, do: IO.write("\r\e[2K")

  defp list_ensembles do
    GenAgentEnsemble.Registry
    |> Registry.select([{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.sort()
  end

  defp format_status(status) when is_map(status) do
    status
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.map_join("\n", fn {k, v} -> "  #{k}: #{inspect(v)}" end)
  end

  defp format_status(other), do: inspect(other, pretty: true)
end
