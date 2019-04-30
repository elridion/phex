defmodule Phex do
  #   Phex - Elixir PHP serialized decoder and encoder.
  #   Copyright (C) 2019  Hans Bernhard Goedeke

  #   This program is free software: you can redistribute it and/or modify
  #   it under the terms of the GNU General Public License as published by
  #   the Free Software Foundation, either version 3 of the License, or
  #   (at your option) any later version.

  #   This program is distributed in the hope that it will be useful,
  #   but WITHOUT ANY WARRANTY; without even the implied warranty of
  #   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  #   GNU General Public License for more details.

  @moduledoc ~S"""
  A PHP serialized decoder and encoder.

  ## Installation

  The package can be installed by adding `phex` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
  [
    {:phex, "~> 0.1.0"}
  ]
  end
  ```

  ## Basic Usage
      iex> Phex.encode!(%{"age" => 42, "name" => "John Doe"})
      "a:2:{s:3:\"age\";i:42;s:4:\"name\";s:8:\"John Doe\";}"

      iex> Phex.decode!("a:2:{s:3:\"age\";i:42;s:4:\"name\";s:8:\"John Doe\";}")
      %{"age" => 42, "name" => "John Doe"}

  ## PHP Serialization
  Currently only maps with keys which are either integers or strings are supported.

  This works in most cases but can create invalid serialized data if the peculiarities of PHP arrays are not taken into account.
  More information can be found in the PHP manual [here](https://www.php.net/manual/en/language.types.array.php).

  As of now supported types are ...

      iex> encode!(nil)
      "N;"

      iex> decode!("N;")
      nil

  ### Boolean
      iex> encode!(true)
      "b:1;"

      iex> decode!("b:0;")
      false

  ### Integer
      iex> encode!(9000)
      "i:9000;"

      iex> decode!("i:-212;")
      -212

  ### Float
      iex> encode!(3.14159265359)
      "d:3.14159265359;"

      iex> decode!("d:6.62607004;")
      6.62607004

  ### String
      iex> encode!("Hello")
      "s:5:\"Hello\";"

      iex> decode!("s:5:\"World\";")
      "World"

  ### Maps (PHP-Arrays)
      iex> encode!(%{"Blue" => 2, "Pink" => 4})
      "a:2:{s:4:\"Blue\";i:2;s:4:\"Pink\";i:4;}"

      iex> decode!("a:2:{s:6:\"Bunker\";s:4:\"Blue\";s:7:\"Buscemi\";s:4:\"Pink\";}")
      %{"Bunker" => "Blue", "Buscemi" => "Pink"}

  ### Objects
      iex> decode!(~S(O:8:"PhpClass":2:{s:21:"PhpClassaPrivateVar";s:16:"A private String";s:10:"aPublicVar";s:15:"A public String";}))
      %{
        :__object__ => "PhpClass",
        "PhpClassaPrivateVar" => "A private String",
        "aPublicVar" => "A public String"
      }
  """
  defstruct [:key]

  def decode!(binary) when is_binary(binary) do
    case decode(binary) do
      {:ok, result, _rest} -> result
      {:error, reason, _rest} -> raise reason
    end
  end

  def decode(binary)

  def decode(<<"N;", rest::binary>>) do
    {:ok, nil, rest}
  end

  def decode(<<"b:0;", rest::binary>>) do
    {:ok, false, rest}
  end

  def decode(<<"b:1;", rest::binary>>) do
    {:ok, true, rest}
  end

  def decode(<<"b:", rest::binary>>) do
    {:error, "can't parse boolean", rest}
  end

  def decode(<<"i:", rest::binary>>) do
    case Integer.parse(rest) do
      {value, <<";", rest::binary>>} ->
        {:ok, value, rest}

      {_val, rest} ->
        {:error, "integer missing terminator", rest}

      :error ->
        {:error, "can't parse integer", rest}
    end
  end

  def decode(<<"d:", rest::binary>>) do
    case Float.parse(rest) do
      {value, <<";", rest::binary>>} ->
        {:ok, value, rest}

      {_val, rest} ->
        {:error, "float missing terminator", rest}

      :error ->
        {:error, "can't parse float", rest}
    end
  end

  def decode(<<"s:", _rest::binary>> = rest) do
    decode_string(rest)
  end

  def decode(<<"a:", rest::binary>>) do
    with {size, <<":", rest::binary>>} <- Integer.parse(rest),
         {:ok, value, rest} <- decode_array(size, rest) do
      {:ok, value, rest}
    else
      {:error, _msg, _rest} = error ->
        error

      {_size, rest} ->
        {:error, "can't parse array - missing size", rest}
    end
  end

  def decode(<<"O:", rest::binary>>) do
    with {size, <<":", rest::binary>>} <- Integer.parse(rest),
         {:ok, name, <<":", rest::binary>>} <- decode_string(size, rest, 0),
         {size, <<":", rest::binary>>} <- Integer.parse(rest),
         {:ok, values, rest} <- decode_object_values(size, rest) do
      {:ok, Map.put(values, :__object__, name), rest}
    else
      {:error, _msg, _rest} = error ->
        error

      {_size, rest} ->
        {:error, "can't parse object - missing size", rest}
    end
  end

  def decode(rest) when is_binary(rest) do
    {:error, "unable to decode", rest}
  end

  defp decode_string(binary, offset \\ 0)

  defp decode_string(<<"s:", rest::binary>>, offset) do
    with {size, <<":", rest::binary>>} <- Integer.parse(rest),
         {:ok, value, <<";", rest::binary>>} <- decode_string(size, rest, offset) do
      {:ok, value, rest}
    end
  end

  defp decode_string(size, binary, offset) do
    case binary do
      <<"\"", rest::binary>> ->
        decode_string("", size, rest, offset)

      rest ->
        {:error, "String missing starting delimiter", rest}
    end
  end

  defp decode_string(acc, size, rest, offset) when offset < 0 do
    decode_string(acc, size + offset, rest, abs(offset))
  end

  defp decode_string(acc, size, <<"\"", rest::binary>>, offset) do
    if size == 0 or size + offset == 0 do
      {:ok, acc, rest}
    else
      {:error, "string length incorrect", rest}
    end
  end

  defp decode_string(acc, size, <<"\\", rest::binary>>, offset) when size > 0 do
    rest
    |> case do
      <<"n", rest::binary>> -> {:ok, "\n", rest}
      <<"r", rest::binary>> -> {:ok, "\r", rest}
      <<"t", rest::binary>> -> {:ok, "\t", rest}
      <<"v", rest::binary>> -> {:ok, "\v", rest}
      <<"e", rest::binary>> -> {:ok, "\e", rest}
      <<"f", rest::binary>> -> {:ok, "\f", rest}
      <<"\\", rest::binary>> -> {:ok, "\\", rest}
      <<"$", rest::binary>> -> {:ok, "$", rest}
      <<"\"", rest::binary>> -> {:ok, "\"", rest}
      <<rest::binary>> -> {:error, "unknown escaped char", rest}
    end
    |> case do
      {:ok, unescaped, rest} ->
        decode_string(acc <> unescaped, size - 1, rest, offset)

      error ->
        error
    end
  end

  defp decode_string(acc, size, <<char::utf8, rest::binary>>, offset) when size > 0 do
    decode_string(<<acc::binary, char::utf8>>, size - byte_size(<<char::utf8>>), rest, offset)
  end

  defp decode_string(acc, size, rest, offset) do
    cond do
      size < 0 and offset == 0 ->
        {:error, "incorrect string length", rest}

      size <= 0 and offset > 0 ->
        decode_string(acc, offset, rest, 0)

      true ->
        {:error, "can't parse string", rest}
    end
  end

  defp decode_array(size, rest)

  defp decode_array(size, <<"{", rest::binary>>) do
    case decode_array(size, rest) do
      {:ok, array, rest} ->
        {:ok, Map.new(array), rest}

      error ->
        error
    end
  end

  defp decode_array(size, <<"}", rest::binary>>) do
    if size == 0 do
      {:ok, [], rest}
    else
      {:error, "incorrect array length", rest}
    end
  end

  defp decode_array(size, rest) do
    with {:ok, key, rest} <- decode(rest),
         {:ok, value, rest} <- decode(rest),
         {:ok, array, rest} <- decode_array(size - 1, rest) do
      {:ok, [{key, value} | array], rest}
    end
  end

  defp decode_object_values(size, rest)

  defp decode_object_values(size, <<"{", rest::binary>>) do
    case decode_object_values(size, rest) do
      {:ok, array, rest} ->
        {:ok, Map.new(array), rest}

      error ->
        error
    end
  end

  defp decode_object_values(size, <<"}", rest::binary>>) do
    if size == 0 do
      {:ok, [], rest}
    else
      {:error, "incorrect array length", rest}
    end
  end

  defp decode_object_values(size, rest) do
    with {:ok, key, rest} <- decode_string(rest, -2),
         {:ok, value, rest} <- decode(rest),
         {:ok, array, rest} <- decode_object_values(size - 1, rest) do
      {:ok, [{key, value} | array], rest}
    end
  end

  def encode!(term) do
    case encode(term) do
      {:ok, result} -> result
      {:error, reason, _rest} -> raise reason
    end
  end

  @spec encode(false | nil | true | binary() | number() | map()) ::
          {:ok, <<_::8, _::_*8>>} | {:error, <<_::96>>, [{any(), any()}]}
  def encode(term)

  def encode(nil) do
    {:ok, "N;"}
  end

  def encode(false) do
    {:ok, "b:0;"}
  end

  def encode(true) do
    {:ok, "b:1;"}
  end

  def encode(number) when is_integer(number) do
    {:ok, "i:" <> Integer.to_string(number) <> ";"}
  end

  def encode(number) when is_float(number) do
    {:ok, "d:" <> Float.to_string(number) <> ";"}
  end

  def encode(binary) when is_binary(binary) do
    {:ok, "s:" <> Integer.to_string(byte_size(binary)) <> ":\"" <> encode_string(binary) <> "\";"}
  end

  def encode(map) when is_map(map) do
    map
    |> Map.to_list()
    |> encode_array()
  end

  defp encode_string(acc \\ <<>>, binary)

  defp encode_string(acc, <<>>) do
    acc
  end

  defp encode_string(acc, rest) when is_binary(rest) do
    rest
    |> case do
      <<"\n", rest::binary>> -> {:ok, "\\n", rest}
      <<"\r", rest::binary>> -> {:ok, "\\r", rest}
      <<"\t", rest::binary>> -> {:ok, "\\t", rest}
      <<"\v", rest::binary>> -> {:ok, "\\v", rest}
      <<"\e", rest::binary>> -> {:ok, "\\e", rest}
      <<"\f", rest::binary>> -> {:ok, "\\f", rest}
      <<"\\", rest::binary>> -> {:ok, "\\\\", rest}
      <<"$", rest::binary>> -> {:ok, "\\$", rest}
      <<"\"", rest::binary>> -> {:ok, "\\\"", rest}
      <<regular::utf8, rest::binary>> -> {:ok, <<regular::utf8>>, rest}
      rest -> {:error, "invalid character", rest}
    end
    |> case do
      {:ok, escaped, rest} -> encode_string(acc <> escaped, rest)
      error -> error
    end
  end

  defp encode_array(rest, acc \\ "", origin \\ "")

  defp encode_array(rest, "", _origin) do
    encode_array(rest, "a:" <> Integer.to_string(length(rest)) <> ":{")
  end

  defp encode_array([{nil, value} | rest], acc, _origin) do
    encode_array([{"", value} | rest], acc)
  end

  defp encode_array([{true, value} | rest], acc, _origin) do
    encode_array([{1, value} | rest], acc)
  end

  defp encode_array([{false, value} | rest], acc, _origin) do
    encode_array([{0, value} | rest], acc)
  end

  defp encode_array([{key, value} | rest], acc, _origin) when is_float(key) do
    encode_array([{Kernel.trunc(key), value} | rest], acc)
  end

  # <<char::utf8, rest::binary>> when char in 48..57 (0..9)
  defp encode_array(
         [{<<char_first::utf8, char_next::utf8, rest_key::binary>> = binary, value} | rest],
         acc,
         origin
       )
       when char_first in 49..57 and rest_key != "" do
    origin = if origin > binary, do: origin, else: binary
    encode_array([{<<char_next::utf8, rest_key::binary>>, value} | rest], acc, origin)
  end

  defp encode_array([{<<char_key::utf8, _rest_key::binary>>, value} | rest], acc, origin)
       when char_key in 49..57 do
    encode_array([{String.to_integer(origin), value} | rest], acc)
  end

  defp encode_array([{key, value} | rest], acc, _origin) when is_integer(key) or is_binary(key) do
    with {:ok, encoded_key} <- encode(key),
         {:ok, encoded_value} <- encode(value) do
      encode_array(rest, acc <> encoded_key <> encoded_value)
    end
  end

  defp encode_array([], acc, _origin) when acc != "" do
    {:ok, acc <> "}"}
  end

  defp encode_array(list, _acc, _origin) do
    {:error, "array encode", list}
  end
end
