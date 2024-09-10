defmodule KeyValueDBTest do
  use ExUnit.Case
  doctest KeyValueDB

  setup do
    {:ok, db} = KeyValueDB.start_link()
    %{db: db}
  end

  describe "SET command" do
    test "sets a new key-value pair", %{db: db} do
      assert KeyValueDB.set(db, "test", 1) == {"FALSE", 1}
      assert KeyValueDB.get(db, "test") == 1
    end

    test "overwrites an existing key", %{db: db} do
      KeyValueDB.set(db, "test", 1)
      assert KeyValueDB.set(db, "test", 2) == {"TRUE", 2}
      assert KeyValueDB.get(db, "test") == 2
    end

    test "sets different types of values", %{db: db} do
      assert KeyValueDB.set(db, "int", 10) == {"FALSE", 10}
      assert KeyValueDB.set(db, "string", "hello") == {"FALSE", "hello"}
      assert KeyValueDB.set(db, "boolean", true) == {"FALSE", true}
    end

    test "sets keys with spaces", %{db: db} do
      assert KeyValueDB.set(db, "key with spaces", "value") == {"FALSE", "value"}
      assert KeyValueDB.get(db, "key with spaces") == "value"
    end
  end

  describe "GET command" do
    test "retrieves an existing value", %{db: db} do
      KeyValueDB.set(db, "test", 1)
      assert KeyValueDB.get(db, "test") == 1
    end

    test "returns NIL for non-existent key", %{db: db} do
      assert KeyValueDB.get(db, "non_existent") == "NIL"
    end
  end

  describe "BEGIN command" do
    test "starts a new transaction", %{db: db} do
      assert KeyValueDB.begin(db) == 1
    end

    test "supports nested transactions", %{db: db} do
      assert KeyValueDB.begin(db) == 1
      assert KeyValueDB.begin(db) == 2
    end
  end

  describe "ROLLBACK command" do
    test "discards changes in the current transaction", %{db: db} do
      KeyValueDB.begin(db)
      KeyValueDB.set(db, "test", 1)
      assert KeyValueDB.get(db, "test") == 1
      assert KeyValueDB.rollback(db) == 0
      assert KeyValueDB.get(db, "test") == "NIL"
    end

    test "returns error when no transaction is active", %{db: db} do
      assert KeyValueDB.rollback(db) == {:error, "No transaction to rollback"}
    end

    test "handles nested transactions correctly", %{db: db} do
      KeyValueDB.begin(db)
      KeyValueDB.set(db, "test", 1)
      KeyValueDB.begin(db)
      KeyValueDB.set(db, "foo", "bar")
      assert KeyValueDB.rollback(db) == 1
      assert KeyValueDB.get(db, "foo") == "NIL"
      assert KeyValueDB.get(db, "test") == 1
    end
  end

  describe "COMMIT command" do
    test "applies changes to the database", %{db: db} do
      KeyValueDB.begin(db)
      KeyValueDB.set(db, "test", 1)
      assert KeyValueDB.commit(db) == 0
      assert KeyValueDB.get(db, "test") == 1
    end

    test "returns error when no transaction is active", %{db: db} do
      assert KeyValueDB.commit(db) == {:error, "No transaction to commit"}
    end

    test "handles nested transactions correctly", %{db: db} do
      KeyValueDB.begin(db)
      KeyValueDB.set(db, "test", 1)
      KeyValueDB.begin(db)
      KeyValueDB.set(db, "foo", "bar")
      assert KeyValueDB.commit(db) == 1
      assert KeyValueDB.get(db, "foo") == "bar"
      assert KeyValueDB.get(db, "test") == 1
      assert KeyValueDB.commit(db) == 0
      assert KeyValueDB.get(db, "foo") == "bar"
      assert KeyValueDB.get(db, "test") == 1
    end
  end

  describe "Edge cases and error handling" do
    test "handles keys with spaces", %{db: db} do
      KeyValueDB.set(db, "key with spaces", "value")
      assert KeyValueDB.get(db, "key with spaces") == "value"
    end

    test "handles string values that look like other types", %{db: db} do
      KeyValueDB.set(db, "looks_like_int", "101")
      assert KeyValueDB.get(db, "looks_like_int") == "101"
      KeyValueDB.set(db, "looks_like_bool", "TRUE")
      assert KeyValueDB.get(db, "looks_like_bool") == "TRUE"
    end

    test "handles escaped quotes in string values", %{db: db} do
      KeyValueDB.set(db, "quoted", "\"test\"")
      assert KeyValueDB.get(db, "quoted") == "\"test\""
    end
  end
end
