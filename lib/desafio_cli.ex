defmodule DesafioCli do
  def main(_args) do
    {:ok, db} = KeyValueDB.start_link()
    IO.puts("Banco KV Cumbuca :)")
    loop(db)
  end

  defp loop(db) do
    IO.write("> ")
    command = IO.gets("") |> String.trim() |> parse_command()
    process_command(db, command)
    loop(db)
  end

  defp parse_command(input) do
    ~r/(?:"([^"]*)"|\S+)/
    |> Regex.scan(input)
    |> Enum.map(fn
      [_, captured] when captured != "" -> captured
      [captured] -> captured
    end)
  end

  defp process_command(db, ["GET", key]) do
    value = KeyValueDB.get(db, key)
    IO.puts(format_output(value))
  end

  defp process_command(db, ["SET", key, value]) do
    {existed, new_data} = KeyValueDB.set(db, key, parse_value(value))
    IO.puts("#{existed} #{format_output(new_data)}")
  end

  defp process_command(db, ["BEGIN"]) do
    level = KeyValueDB.begin(db)
    IO.puts("#{level}")
  end

  defp process_command(db, ["ROLLBACK"]) do
    level = KeyValueDB.rollback(db)
    IO.puts("#{level}")
  end

  defp process_command(db, ["COMMIT"]) do
    level = KeyValueDB.commit(db)
    IO.puts("#{level}")
  end

  defp process_command(_db, ["GET"]) do
    IO.puts("ERR - Syntax error: GET command requires a key. Example: GET <key>")
  end

  defp process_command(_db, ["SET"]) do
    IO.puts("ERR - Syntax error: SET command requires a key and a value. Example: SET <key> <value>")
  end

  defp process_command(_db, ["SET", _key]) do
    IO.puts("ERR - Syntax error: SET command requires a value. Example: SET <key> <value>")
  end

  defp process_command(_db, command) do
    IO.puts("ERR - Invalid command: #{Enum.join(command, " ")}")
  end

  defp format_output(value) when is_binary(value), do: value
  defp format_output(value), do: inspect(value)

  defp parse_value("TRUE"), do: true
  defp parse_value("FALSE"), do: false
  defp parse_value(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> value
    end
  end
end

# KeyValueDB

defmodule KeyValueDB do
  def start_link do
    Agent.start_link(fn -> %{data: %{}, transaction_stack: []} end)
  end

  def get(db, key) do
    Agent.get(db, fn state ->
      get_in(state.data, [key]) || :NIL
    end)
  end

  def set(db, key, value) do
    Agent.get_and_update(db, fn state ->
      existed = Map.has_key?(state.data, key)
      new_data = Map.put(state.data, key, value)
      new_state = %{state | data: new_data}
      {{String.upcase(to_string(existed)), value}, new_state}
    end)
  end

  def begin(db) do
    Agent.update(db, fn state ->
      %{state | transaction_stack: [state.data | state.transaction_stack]}
    end)
    Agent.get(db, fn state -> length(state.transaction_stack) end)
  end

  def rollback(db) do
    Agent.update(db, fn state ->
      case state.transaction_stack do
        [head | tail] -> %{state | data: head, transaction_stack: tail}
        [] -> state
      end
    end)
    Agent.get(db, fn state -> length(state.transaction_stack) end)
  end

  def commit(db) do
    Agent.update(db, fn state ->
      case state.transaction_stack do
        [_ | tail] -> %{state | transaction_stack: tail}
        [] -> state
      end
    end)
    Agent.get(db, fn state -> length(state.transaction_stack) end)
  end
end
