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

  def parse_command(input) do
    ~r/(?:"([^"]*)"|\S+)/
    |> Regex.scan(input)
    |> Enum.map(fn
      [_, captured] when captured != "" -> captured
      [captured] -> captured
    end)
  end

  def process_command(db, ["GET", key]) do
    value = KeyValueDB.get(db, key)
    IO.puts(format_output(value))
  end

  def process_command(db, ["SET", key, value]) do
    {existed, new_data} = KeyValueDB.set(db, key, parse_value(value))
    IO.puts("#{existed} #{format_output(new_data)}")
  end

  def process_command(db, ["BEGIN"]) do
    level = KeyValueDB.begin(db)
    IO.puts("#{level}")
  end

  def process_command(db, ["ROLLBACK"]) do
    case KeyValueDB.rollback(db) do
      {:error, message} -> IO.puts("ERR #{message}")
      level -> IO.puts("#{level}")
    end
  end

  def process_command(db, ["COMMIT"]) do
    case KeyValueDB.commit(db) do
      {:error, message} -> IO.puts("ERR #{message}")
      level -> IO.puts("#{level}")
    end
  end
  def process_command(_db, ["GET"]) do
    IO.puts("ERR - Syntax error: GET command requires a key. Example: GET <key>")
  end

  def process_command(_db, ["SET"]) do
    IO.puts("ERR - Syntax error: SET command requires a key and a value. Example: SET <key> <value>")
  end

  def process_command(_db, ["SET", key]) do
    IO.puts("ERR - Syntax error: SET command requires a value. Example: SET #{key} <value>")
  end

  def process_command(_db, command) do
    IO.puts("ERR - Invalid command: #{Enum.join(command, " ")}")
  end

  def format_output("NIL"), do: "NIL"
  def format_output(value) when is_binary(value), do: value
  def format_output(value), do: inspect(value)

  def parse_value("TRUE"), do: true
  def parse_value("FALSE"), do: false
  def parse_value(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> value
    end
  end
end
