defmodule Phex.Decode do
  @moduledoc false

  def decode(term, opt \\ :naive)

  def decode(<<"N;", rest::binary>>, _opt) do
    {:ok, nil, rest}
  end

  def decode(<<"b:0;", rest::binary>>, _opt) do
    {:ok, false, rest}
  end

  def decode(<<"b:1;", rest::binary>>, _opt) do
    {:ok, true, rest}
  end

  def decode(<<"b:", rest::binary>>, _opt) do
    {:error, "can't parse boolean", rest}
  end

  def decode(<<"i:", rest::binary>>, _opt) do
    case Integer.parse(rest) do
      {value, <<";", rest::binary>>} ->
        {:ok, value, rest}

      {_val, rest} ->
        {:error, "integer missing terminator", rest}

      :error ->
        {:error, "can't parse integer", rest}
    end
  end

  def decode(<<"d:", rest::binary>>, _opt) do
    case Float.parse(rest) do
      {value, <<";", rest::binary>>} ->
        {:ok, value, rest}

      {_val, rest} ->
        {:error, "float missing terminator", rest}

      :error ->
        {:error, "can't parse float", rest}
    end
  end

  def decode(<<"s:", _rest::binary>> = rest, _opt) do
    decode_string(rest)
  end

  def decode(<<"a:", rest::binary>>, opt) do
    with {size, <<":", rest::binary>>} <- Integer.parse(rest),
         {:ok, values, rest} <- decode_array(size, rest) do
      values =
        case opt do
          :naive -> Map.new(values)
          _ -> values
        end

      {:ok, values, rest}
    else
      {:error, _msg, _rest} = error ->
        error

      {_size, rest} ->
        {:error, "can't parse array - missing size", rest}
    end
  end

  def decode(<<"O:", rest::binary>>, _opt) do
    with {size, <<":", rest::binary>>} <- Integer.parse(rest),
         {:ok, class, <<":", rest::binary>>} <- decode_string(size, rest),
         {size, <<":", rest::binary>>} <- Integer.parse(rest),
         {:ok, values, rest} <- decode_object_values(size, rest, class) do
      {:ok, Map.put(values, :__object__, class), rest}
    else
      {:error, _msg, _rest} = error ->
        error

      {_size, rest} ->
        {:error, "can't parse object - missing size", rest}
    end
  end

  def decode(rest, _opt) when is_binary(rest) do
    {:error, "unable to decode", rest}
  end

  defp decode_string(binary)

  defp decode_string(<<"s:", rest::binary>>) do
    with {size, <<":", rest::binary>>} <- Integer.parse(rest),
         {:ok, value, <<";", rest::binary>>} <- decode_string(size, rest) do
      {:ok, value, rest}
    end
  end

  defp decode_string(size, <<"\"", binary::binary>>) do
    case binary do
      <<string::bytes-size(size), "\"", rest::binary>> ->
        {:ok, string, rest}

      _ ->
        {:error, "string missing terminator", binary}
    end
  end

  defp decode_string(_size, rest) do
    {:error, "cant't parse string", rest}
  end

  defp decode_array(size, rest)

  defp decode_array(size, <<"{", rest::binary>>) do
    case decode_array(size, rest) do
      {:ok, array, rest} ->
        {:ok, array, rest}

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
    with {:ok, key, rest} <- decode(rest, %{array: :naive}),
         {:ok, value, rest} <- decode(rest),
         {:ok, array, rest} <- decode_array(size - 1, rest) do
      {:ok, [{key, value} | array], rest}
    end
  end

  defp decode_object_values(size, binary, class) when is_binary(class) do
    decode_object_values(size, binary, {class, byte_size(class)})
  end

  defp decode_object_values(size, <<"{", rest::binary>>, class) do
    case decode_object_values(size, rest, class) do
      {:ok, array, rest} ->
        {:ok, Map.new(array), rest}

      error ->
        error
    end
  end

  defp decode_object_values(size, <<"}", rest::binary>>, _class) do
    if size == 0 do
      {:ok, [], rest}
    else
      {:error, "incorrect array length", rest}
    end
  end

  defp decode_object_values(size, binary, class) do
    with {:ok, key, rest} <- decode_object_key(binary, class),
         {:ok, value, rest} <- decode(rest),
         {:ok, array, rest} <- decode_object_values(size - 1, rest, class) do
      {:ok, [{key, value} | array], rest}
    end
  end

  defp decode_object_key(binary, {class, size}) do
    case decode_string(binary) do
      {:ok, <<0, ^class::bytes-size(size), 0, key::binary>>, rest} -> {:ok, key, rest}
      any -> any
    end
  end
end
