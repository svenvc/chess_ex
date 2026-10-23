defmodule Chess.UCI.CLI do
  @moduledoc """
  The executable entry point of the UCI interface.

  UCI runs on the standard input and output of the engine process, so this
  module reads commands from stdin and writes the answers to stdout. It is the
  `main_module` of the escript built by `mix escript.build`:

      mix escript.build
      ./chess_ex

  A reader process collects the commands, while the main process owns stdout
  and the game state. A `go` command starts the search in a process of its
  own, so that `isready`, `stop` and `quit` are answered while the engine is
  thinking. `stop` kills the search and answers with the best move of the last
  completed iteration, or with the first legal move when no iteration has
  completed yet.

  Nothing but UCI lines is written to stdout: diagnostics belong on stderr.
  """

  alias Chess.{Rules, Search, UCI}

  @next_iteration_factor 16

  @doc """
  The escript entry point. The command line arguments are not used.
  """
  def main(_arguments) do
    run()
  end

  @doc """
  Run the UCI loop on stdin and stdout until `quit` or the end of the input.
  """
  def run do
    parent = self()
    reader = spawn(fn -> read_lines(parent) end)
    loop(%{uci: UCI.new(), reader: reader, search: nil, eof: false})
  end

  ## Input

  # Read stdin line by line in a process of its own, so the main loop can
  # still receive search messages while IO.gets/1 blocks. A closed input
  # becomes the same :uci_eof event as an IO error.
  defp read_lines(parent) do
    case IO.gets("") do
      :eof ->
        send(parent, :uci_eof)

      {:error, _reason} ->
        send(parent, :uci_eof)

      line ->
        send(parent, {:uci_line, String.trim_trailing(line)})
        read_lines(parent)
    end
  end

  ## Main loop

  # Wait for the next event. Commands, search progress and the monitor signal
  # of the search process all arrive here, which keeps all output on stdout in
  # one process and therefore in order.
  defp loop(state) do
    receive do
      {:uci_line, line} ->
        handle_line(state, line)

      :uci_eof ->
        handle_eof(state)

      {:uci_info, search_ref, line} ->
        if current_search?(state, search_ref), do: IO.puts(line)
        loop(state)

      {:uci_progress, search_ref, move} ->
        loop(progress(state, search_ref, move))

      {:uci_bestmove, search_ref, move} ->
        handle_bestmove(state, search_ref, move)

      {:DOWN, monitor_ref, :process, pid, reason} ->
        handle_down(state, monitor_ref, pid, reason)
    end
  end

  # Let Chess.UCI translate the line, then carry out its instruction. A
  # position or a new game first makes a running search obsolete.
  defp handle_line(state, line) do
    state = stop_for_new_position(state, line)

    case UCI.handle(state.uci, line) do
      {:reply, lines, uci} ->
        write(lines)
        continue(%{state | uci: uci})

      {:search, plan, uci} ->
        start_search(%{state | uci: uci}, plan)

      {:stop, uci} ->
        continue(stop_search(%{state | uci: uci}, true))

      {:quit, uci} ->
        quit(%{state | uci: uci})
    end
  end

  # A closed input is a quit request. If a search is still running, remember
  # the EOF and wait for its best move instead of dropping the answer; this
  # makes a piped `go` work.
  defp handle_eof(%{search: nil} = state), do: quit(state)

  defp handle_eof(state), do: loop(%{state | eof: true})

  # Answer with the move the search finished with. A best move from a search
  # that was already replaced or stopped is ignored.
  defp handle_bestmove(state, search_ref, move) do
    if current_search?(state, search_ref) do
      write(["bestmove #{UCI.to_uci(move)}"])
      continue(%{state | search: nil})
    else
      loop(state)
    end
  end

  # A search that leaves normally has sent its best move already. An abnormal
  # exit must still answer the GUI, with the best move found so far.
  defp handle_down(
         %{search: %{pid: pid, monitor_ref: monitor_ref}} = state,
         monitor_ref,
         pid,
         reason
       ) do
    if reason != :normal do
      case state.search.last || state.search.fallback do
        nil -> write(["bestmove 0000"])
        move -> write(["bestmove #{UCI.to_uci(move)}"])
      end
    end

    continue(%{state | search: nil})
  end

  # A DOWN from a search that has already been stopped or replaced is stale.
  defp handle_down(state, _monitor_ref, _pid, _reason), do: loop(state)

  # Leave when the input is exhausted and nothing is searching any more;
  # otherwise keep waiting for the active search's best move.
  defp continue(%{eof: true, search: nil} = state), do: quit(state)

  defp continue(state), do: loop(state)

  # Stop both helper processes and return from run/0.
  defp quit(state) do
    stop_search(state, false)
    Process.exit(state.reader, :kill)
    :ok
  end

  ## Search

  # Start a search unless there is no legal move at all. The first legal move
  # is the fallback: it is answered if `stop` arrives before one iteration of
  # the search has completed.
  defp start_search(state, plan) do
    state = stop_search(state, false)
    game = state.uci.game

    case Rules.legal_moves(game) do
      [] ->
        write(["bestmove 0000"])
        continue(state)

      [fallback | _moves] ->
        search_ref = make_ref()
        parent = self()

        {pid, monitor_ref} =
          spawn_monitor(fn -> search(game, plan, fallback, parent, search_ref) end)

        search = %{
          pid: pid,
          monitor_ref: monitor_ref,
          ref: search_ref,
          fallback: fallback,
          last: fallback
        }

        continue(%{state | search: search})
    end
  end

  # Iterative deepening in the search process. Each completed depth is sent
  # to the main loop as an info line and improves the move `stop` would
  # answer with. The exception handler keeps the GUI from waiting forever if
  # the search ever fails.
  defp search(game, plan, fallback, parent, search_ref) do
    deadline = if plan.budget_ms, do: now() + plan.budget_ms
    started = now()

    best =
      Enum.reduce_while(1..plan.max_depth, fallback, fn depth, best ->
        if depth > 1 and expired?(deadline) do
          {:halt, best}
        else
          iteration_started = now()

          case Search.best_move(game, depth: depth, randomize: false) do
            {:ok, move, score} ->
              elapsed = now() - started
              iteration = now() - iteration_started

              send(parent, {:uci_info, search_ref, UCI.info_line(depth, score, elapsed, move)})
              send(parent, {:uci_progress, search_ref, move})

              # The next iteration is usually several times more expensive
              # than this one. Do not start it when it is likely to overrun
              # the budget; the search itself cannot be interrupted halfway.
              if likely_in_budget?(deadline, iteration), do: {:cont, move}, else: {:halt, move}

            {:error, _status} ->
              {:halt, best}
          end
        end
      end)

    send(parent, {:uci_bestmove, search_ref, best})
  rescue
    _error -> send(parent, {:uci_bestmove, search_ref, fallback})
  end

  # Do not start the next iteration when the current one suggests that it
  # would overrun the time budget. A search iteration cannot be interrupted
  # halfway, so this is only a heuristic; the constant is deliberately
  # conservative because deeper iterations grow quickly.
  defp likely_in_budget?(nil, _iteration), do: true

  defp likely_in_budget?(deadline, iteration) do
    now() + iteration * @next_iteration_factor < deadline
  end

  # True once the soft deadline has passed. A nil deadline never expires.
  defp expired?(nil), do: false
  defp expired?(deadline), do: now() >= deadline

  defp now, do: System.monotonic_time(:millisecond)

  # Search messages carry the reference of the search that produced them, so
  # messages from a stopped or replaced search can be dropped.
  defp current_search?(%{search: %{ref: search_ref}}, search_ref), do: true
  defp current_search?(_state, _search_ref), do: false

  # Remember the best move of the latest completed depth for a later `stop`.
  defp progress(%{search: %{ref: search_ref}} = state, search_ref, move) do
    %{state | search: %{state.search | last: move}}
  end

  defp progress(state, _search_ref, _move), do: state

  # A new position or a new game makes a running search obsolete.
  defp stop_for_new_position(state, line) do
    case line |> String.trim() |> String.split(~r/\s+/, parts: 2, trim: true) do
      ["position" | _] -> stop_search(state, false)
      ["ucinewgame"] -> stop_search(state, false)
      _other -> state
    end
  end

  # Kill the search process. With answer? set, report its latest move so that
  # `stop` always gets a bestmove; a replaced search is stopped silently.
  defp stop_search(%{search: nil} = state, _answer?), do: state

  defp stop_search(%{search: search} = state, answer?) do
    Process.exit(search.pid, :kill)

    if answer? do
      case search.last || search.fallback do
        nil -> write(["bestmove 0000"])
        move -> write(["bestmove #{UCI.to_uci(move)}"])
      end
    end

    %{state | search: nil}
  end

  ## Output

  # All protocol output goes through here, one line at a time.
  defp write(lines) do
    Enum.each(lines, &IO.puts/1)
  end
end
