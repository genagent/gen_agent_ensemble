defmodule GenAgentEnsemble.ChatTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias GenAgent.Backends.Mock
  alias GenAgent.Event
  alias GenAgentEnsemble.Strategies.Solo
  alias GenAgentEnsemble.TestAgent

  setup do
    name = "chat-#{System.unique_integer([:positive])}"
    on_exit(fn -> safe_stop(name) end)
    %{name: name}
  end

  defp safe_stop(name) do
    try do
      GenAgentEnsemble.stop(name)
    catch
      :exit, _ -> :ok
    end
  end

  defp start_ensemble(name, scripts) do
    GenAgentEnsemble.start_link(
      name: name,
      strategy: Solo,
      opts: [agent: {"#{name}-a", TestAgent, [backend: Mock, scripts: scripts]}]
    )
  end

  test "prompt/response round trip, then /exit", %{name: name} do
    {:ok, _} =
      start_ensemble(name, [
        [Event.new(:result, %{text: "hello there"})]
      ])

    output =
      capture_io("say hi\n/exit\n", fn ->
        assert :ok == GenAgentEnsemble.Chat.start(name)
      end)

    assert output =~ "hello there"
    assert output =~ "bye"
  end

  test "/help lists commands", %{name: name} do
    {:ok, _} = start_ensemble(name, [])

    output =
      capture_io("/help\n/exit\n", fn ->
        GenAgentEnsemble.Chat.start(name)
      end)

    assert output =~ "/status"
    assert output =~ "/history"
    assert output =~ "/switch"
    assert output =~ "/exit"
  end

  test "/history shows turns taken this session", %{name: name} do
    {:ok, _} =
      start_ensemble(name, [
        [Event.new(:result, %{text: "ok"})]
      ])

    output =
      capture_io("first question\n/history\n/exit\n", fn ->
        GenAgentEnsemble.Chat.start(name)
      end)

    # Before /history: saw response "ok"
    assert output =~ "ok"
    # After /history: saw both sides echoed
    assert output =~ "first question"
  end

  test "/list shows running ensembles", %{name: name} do
    {:ok, _} = start_ensemble(name, [])

    output =
      capture_io("/list\n/exit\n", fn ->
        GenAgentEnsemble.Chat.start(name)
      end)

    assert output =~ name
  end

  test "unknown command prints error and loops", %{name: name} do
    {:ok, _} = start_ensemble(name, [])

    output =
      capture_io("/bogus\n/exit\n", fn ->
        GenAgentEnsemble.Chat.start(name)
      end)

    assert output =~ "unknown command"
    assert output =~ "bye"
  end

  test "non-existent ensemble returns error without entering loop" do
    output =
      capture_io(fn ->
        assert {:error, :not_found} == GenAgentEnsemble.Chat.start("nope-nope-nope")
      end)

    assert output =~ "ensemble not found"
  end

  test "/switch moves to another ensemble", %{name: name} do
    other = "chat-other-#{System.unique_integer([:positive])}"
    on_exit(fn -> safe_stop(other) end)

    {:ok, _} =
      start_ensemble(name, [
        [Event.new(:result, %{text: "first"})]
      ])

    {:ok, _} =
      start_ensemble(other, [
        [Event.new(:result, %{text: "second"})]
      ])

    output =
      capture_io("hi\n/switch #{other}\nhi\n/exit\n", fn ->
        GenAgentEnsemble.Chat.start(name)
      end)

    assert output =~ "first"
    assert output =~ "switched to"
    assert output =~ "second"
  end

  test "EOF exits cleanly", %{name: name} do
    {:ok, _} = start_ensemble(name, [])

    output =
      capture_io("", fn ->
        GenAgentEnsemble.Chat.start(name)
      end)

    assert output =~ "bye"
  end
end
