defmodule Phex.Encode do
  @moduledoc false
  defguard is_valid_key(key) when is_binary(key) or is_number(key) or is_atom(key)

  def encode(term)

  def encode(nil) do
    "N;"
  end

  def encode(false) do
    "b:0;"
  end

  def encode(true) do
    "b:1;"
  end

  def encode(atom) when is_atom(atom) do
    Atom.to_string(atom)
  end

  def encode(number) when is_integer(number) do
    ["i:", encode_integer(number), ?;]
  end

  def encode(number) when is_float(number) do
    ["d:", encode_float(number), ?;]
  end

  def encode(binary) when is_binary(binary) do
    ["s:", encode_integer(byte_size(binary)), ":\"", binary, "\";"]
  end

  def encode(map) when is_map(map) do
    map
    |> Map.to_list()
    |> encode()
  end

  def encode(list) when is_list(list) do
    ["a:", encode_integer(length(list)), ":{" | encode_list(list)]
  end

  defp encode_integer(integer) do
    Integer.to_string(integer)
  end

  defp encode_float(float) do
    :io_lib_format.fwrite_g(float)
  end

  defp encode_list(list, visited \\ [])

  defp encode_list([{key, value} | rest], visited) when is_valid_key(key) do
    array_key = cast_key(key)

    if array_key in visited,
      do: raise(Phex.EncodeError, message: "Duplicate key: #{inspect(array_key)}")

    [
      encode(array_key),
      encode(value)
      | encode_list(rest, [array_key | visited])
    ]
  end

  defp encode_list([], _visited) do
    [?}]
  end

  defp cast_key(key)

  defp cast_key(<<first, _::binary>> = key) when first in ?1..?9 do
    case Integer.parse(key) do
      {key, ""} -> key
      _ -> key
    end
  end

  defp cast_key(key) when is_float(key) do
    trunc(key)
  end

  defp cast_key(key) when is_atom(key) do
    case key do
      true -> 1
      false -> 0
      nil -> ""
      key -> Atom.to_string(key)
    end
  end

  defp cast_key(key) do
    key
  end
end
