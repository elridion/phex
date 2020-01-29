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
      assert {:ok, "hello\nwörld", ""} = decode("s:12:\"hello\nwörld\";")
      assert {:ok, "hello_wörld", ""} = decode("s:12:\"hello_wörld\";")
    end

    test "array" do
      assert {:ok, %{"a" => 1, "b" => 2}, ""} = decode("a:2:{s:1:\"a\";i:1;s:1:\"b\";i:2;}")
      assert {:error, _msg, _rest} = decode("a:2{s:1:\"a\";i:1;s:1:\"b\";i:2;}")
    end

    test "objects" do
      object =
        "TzoxOiJBIjo1OntzOjE0OiIAQQBhUHJpdmF0ZVZhciI7czo3OiJwcml2YXRlIjtzOjE0OiIAQQBhUHJpdmF0ZU9iaiI7TzoxOiJ" <>
          "BIjo1OntzOjE0OiIAQQBhUHJpdmF0ZVZhciI7czo3OiJwcml2YXRlIjtzOjE0OiIAQQBhUHJpdmF0ZU9iaiI7TjtzOjEwOiJh" <>
          "UHVibGljVmFyIjtzOjY6InB1YmxpYyI7czoxMDoiYVB1YmxpY09iaiI7TjtzOjQ6ImtpbmQiO3M6NzoicHJpdmF0ZSI7fXM6M" <>
          "TA6ImFQdWJsaWNWYXIiO3M6NjoicHVibGljIjtzOjEwOiJhUHVibGljT2JqIjtPOjE6IkEiOjU6e3M6MTQ6IgBBAGFQcml2YX" <>
          "RlVmFyIjtzOjc6InByaXZhdGUiO3M6MTQ6IgBBAGFQcml2YXRlT2JqIjtOO3M6MTA6ImFQdWJsaWNWYXIiO3M6NjoicHVibGl" <>
          "jIjtzOjEwOiJhUHVibGljT2JqIjtOO3M6NDoia2luZCI7czo2OiJwdWJsaWMiO31zOjQ6ImtpbmQiO047fQ=="

      serialized = Base.decode64!(object)

      objects = %{
        :__object__ => "A",
        "aPrivateObj" => %{
          :__object__ => "A",
          "aPrivateObj" => nil,
          "aPrivateVar" => "private",
          "aPublicObj" => nil,
          "aPublicVar" => "public",
          "kind" => "private"
        },
        "aPrivateVar" => "private",
        "aPublicObj" => %{
          :__object__ => "A",
          "aPrivateObj" => nil,
          "aPrivateVar" => "private",
          "aPublicObj" => nil,
          "aPublicVar" => "public",
          "kind" => "public"
        },
        "aPublicVar" => "public",
        "kind" => nil
      }

      assert {:ok, objects, ""} == decode(serialized)
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
      assert {:ok, "s:12:\"Hello Wörld\";"} = encode("Hello Wörld")
      assert {:ok, "s:11:\"hello_world\";"} = encode("hello_world")
      assert {:ok, "s:12:\"hello\nwörld\";"} = encode("hello\nwörld")
    end

    test "array" do
      assert {:ok, "a:2:{s:1:\"a\";i:1;s:1:\"b\";i:2;}"} = encode(%{"a" => 1, "b" => 2})
      assert {:ok, "a:2:{s:1:\"a\";i:1;s:1:\"b\";i:2;}"} = encode(%{:a => 1, :b => 2})
    end

    test "array casts" do
      iarr = encode!(%{1 => "a"})
      sarr = encode!(%{"1" => "a"})
      farr = encode!(%{1.5 => "a"})
      barr = encode!(%{true => "a"})

      assert barr == iarr
      assert iarr == sarr
      assert sarr == farr
      assert farr == barr
    end

    test "array integer cast" do
      assert {:ok, ~s(a:1:{s:1:"0";s:5:"value";})} = encode(%{"0" => "value"})

      assert {:ok, ~s(a:1:{i:1;s:5:"value";})} = encode(%{"1" => "value"})
      assert {:ok, ~s(a:1:{i:2;s:5:"value";})} = encode(%{"2" => "value"})
      assert {:ok, ~s(a:1:{i:3;s:5:"value";})} = encode(%{"3" => "value"})
      assert {:ok, ~s(a:1:{i:4;s:5:"value";})} = encode(%{"4" => "value"})
      assert {:ok, ~s(a:1:{i:5;s:5:"value";})} = encode(%{"5" => "value"})
      assert {:ok, ~s(a:1:{i:6;s:5:"value";})} = encode(%{"6" => "value"})
      assert {:ok, ~s(a:1:{i:7;s:5:"value";})} = encode(%{"7" => "value"})
      assert {:ok, ~s(a:1:{i:8;s:5:"value";})} = encode(%{"8" => "value"})
      assert {:ok, ~s(a:1:{i:9;s:5:"value";})} = encode(%{"9" => "value"})
      assert {:ok, ~s(a:1:{i:10;s:5:"value";})} = encode(%{"10" => "value"})

      assert {:ok, ~s(a:1:{s:2:"01";s:5:"value";})} = encode(%{"01" => "value"})

      assert {:ok, ~s(a:1:{s:2:"+1";s:5:"value";})} = encode(%{"+1" => "value"})

      assert {:ok, ~s(a:1:{s:2:"-1";s:5:"value";})} = encode(%{"-1" => "value"})
    end

    test "array float cast" do
      assert {:ok, ~s(a:1:{i:8;s:5:"value";})} = encode(%{8.5 => "value"})
    end

    test "array boolean cast" do
      assert {:ok, ~s(a:1:{i:0;s:5:"value";})} = encode(%{false => "value"})
      assert {:ok, ~s(a:1:{i:1;s:5:"value";})} = encode(%{true => "value"})
    end
  end
end
