defmodule PhexTest do
  use ExUnit.Case
  doctest Phex, import: true

  import Phex

  describe "decode" do
    test "nil" do
      assert {:ok, nil, ""} = decode("N;")
    end

    test "boolean" do
      assert {:ok, true, ""} = decode("b:1;")
      assert {:ok, false, ""} = decode("b:0;")
      assert {:error, _msg, _rest} = decode("b:a;")
      assert {:error, _msg, _rest} = decode("b:3;")
    end

    test "integer" do
      assert {:ok, 33, ""} = decode("i:33;")
      assert {:ok, -33, ""} = decode("i:-33;")
      assert {:error, _msg, _rest} = decode("i:-33.23;")
    end

    test "float" do
      assert {:ok, 33.0, ""} = decode("d:33.0;")
      assert {:ok, -33.0, ""} = decode("d:-33.0;")
      assert {:ok, -33.23, ""} = decode("d:-33.23;")
      assert {:error, _msg, _rest} = decode("d:-33,23;")
      # assert {:error, _msg, _rest} = decode("d:33;")
    end

    test "string" do
      assert {:ok, "hello_world", ""} = decode("s:11:\"hello_world\";")
      assert {:error, _msg, _rest} = decode("s:12:\"hello_world\";")
      assert {:error, _msg, _rest} = decode("s:10:\"hello_world\";")

      assert {:ok, "hello_wörld", ""} = decode("s:12:\"hello_wörld\";")
      assert {:ok, "hello\nwörld", ""} = decode("s:12:\"hello\\nwörld\";")
      assert {:ok, "hello_wörld", ""} = decode("s:12:\"hello_wörld\";")
    end

    test "array" do
      assert {:ok, %{"a" => 1, "b" => 2}, ""} = decode("a:2:{s:1:\"a\";i:1;s:1:\"b\";i:2;}")
      assert {:error, _msg, _rest} = decode("a:2{s:1:\"a\";i:1;s:1:\"b\";i:2;}")
    end
  end

  describe "encode" do
    test "nil" do
      assert {:ok, "N;"} = encode(nil)
    end

    test "boolean" do
      assert {:ok, "b:1;"} = encode(true)
      assert {:ok, "b:0;"} = encode(false)
    end

    test "integer" do
      assert {:ok, "i:33;"} = encode(33)
      assert {:ok, "i:-33;"} = encode(-33)
    end

    test "float" do
      assert {:ok, "d:33.0;"} = encode(33.0)
      assert {:ok, "d:-33.0;"} = encode(-33.0)
      assert {:ok, "d:-33.23;"} = encode(-33.23)
    end

    test "string" do
      assert {:ok, "s:11:\"hello_world\";"} = encode("hello_world")
      assert {:ok, "s:12:\"hello\\nwörld\";"} = encode("hello\nwörld")
    end

    test "array" do
      assert {:ok, "a:2:{s:1:\"a\";i:1;s:1:\"b\";i:2;}"} = encode(%{"a" => 1, "b" => 2})
    end
  end
end
