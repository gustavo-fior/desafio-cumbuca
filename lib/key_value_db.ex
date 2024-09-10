defmodule KeyValueDB do
  def start_link do
    Agent.start_link(fn -> %{data: %{}, transaction_stack: []} end)
  end

  def get(db, key) do
    Agent.get(db, fn state ->
      lookup_value(state, key)
    end)
  end

  def set(db, key, value) do
    Agent.get_and_update(db, fn state ->
      case state.transaction_stack do
        [] ->
          existed = Map.has_key?(state.data, key)
          new_data = Map.put(state.data, key, value)
          new_state = %{state | data: new_data}
          {{String.upcase(to_string(existed)), value}, new_state}
        [current_transaction | rest] ->
          existed = has_key?(state, key)
          new_transaction = Map.put(current_transaction, key, value)
          new_state = %{state | transaction_stack: [new_transaction | rest]}
          {{String.upcase(to_string(existed)), value}, new_state}
      end
    end)
  end

  def begin(db) do
    Agent.get_and_update(db, fn state ->
      new_transaction = %{}
      new_stack = [new_transaction | state.transaction_stack]
      new_state = %{state | transaction_stack: new_stack}
      {length(new_stack), new_state}
    end)
  end

  def rollback(db) do
    Agent.get_and_update(db, fn state ->
      case state.transaction_stack do
        [] ->
          {{:error, "No transaction to rollback"}, state}
        [_ | rest] ->
          new_state = %{state | transaction_stack: rest}
          {length(rest), new_state}
      end
    end)
  end

  def commit(db) do
    Agent.get_and_update(db, fn state ->
      case state.transaction_stack do
        [] ->
          {{:error, "No transaction to commit"}, state}
        [current_transaction | rest] ->
          new_stack = case rest do
            [] -> []
            [parent | grandparents] ->
              [Map.merge(parent, current_transaction) | grandparents]
          end
          new_data = if rest == [], do: Map.merge(state.data, current_transaction), else: state.data
          new_state = %{state | data: new_data, transaction_stack: new_stack}
          {length(new_stack), new_state}
      end
    end)
  end

  defp lookup_value(state, key) do
    Enum.reduce_while(state.transaction_stack, :not_found, fn transaction, acc ->
      case Map.get(transaction, key) do
        nil -> {:cont, acc}
        value -> {:halt, value}
      end
    end)
    |> case do
      :not_found -> Map.get(state.data, key, "NIL")
      value -> value
    end
  end

  defp has_key?(state, key) do
    Enum.any?(state.transaction_stack, &Map.has_key?(&1, key)) || Map.has_key?(state.data, key)
  end
end
