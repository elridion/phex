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
  """

  @doc false
  def decode!(binary) when is_binary(binary) do
    case decode(binary) do
      {:ok, result, _rest} -> result
      {:error, reason, _rest} -> raise reason
    end
  end

  @doc false
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

  def decode(<<"s:", rest::binary>>) do
    with {size, <<":", rest::binary>>} <- Integer.parse(rest),
         {:ok, value, rest} <- decode_string(size, rest) do
      {:ok, value, rest}
    end
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
    {:error, "Objects are currently not supported", rest}
  end

  def decode(rest) when is_binary(rest) do
    {:error, "unable to decode", rest}
  end

  defp decode_string(size, <<"\"", rest::binary>>) do
    decode_string("", size, rest)
  end

  defp decode_string(_size, rest) do
    {:error, rest}
  end

  defp decode_string(acc, size, <<"\";", rest::binary>>) do
    if size == 0 do
      {:ok, acc, rest}
    else
      {:error, "string length incorrect", rest}
    end
  end

  defp decode_string(acc, size, <<"\\", rest::binary>>) when size > 0 do
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
        decode_string(acc <> unescaped, size - 1, rest)

      error ->
        error
    end
  end

  defp decode_string(acc, size, <<char::utf8, rest::binary>>) when size > 0 do
    decode_string(<<acc::binary, char::utf8>>, size - byte_size(<<char::utf8>>), rest)
  end

  defp decode_string(_acc, size, rest) when size <= 0 do
    {:error, "incorrect string length", rest}
  end

  defp decode_string(_acc, _size, rest) do
    {:error, "can't pares string", rest}
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

  @doc false
  def encode!(term) do
    case encode(term) do
      {:ok, result} -> result
      {:error, reason, _rest} -> raise reason
    end
  end

  @doc false
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

  defp encode_array(rest, acc \\ "")

  defp encode_array(rest, "") do
    encode_array(rest, "a:" <> Integer.to_string(length(rest)) <> ":{")
  end

  defp encode_array([{key, value} | rest], acc) when is_binary(key) or is_integer(key) do
    with {:ok, encoded_key} <- encode(key),
         {:ok, encoded_value} <- encode(value) do
      encode_array(rest, acc <> encoded_key <> encoded_value)
    end
  end

  defp encode_array([], acc) when acc != "" do
    {:ok, acc <> "}"}
  end

  defp encode_array(list, _acc) do
    {:error, "array encode", list}
  end
end