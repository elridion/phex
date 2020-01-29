defmodule Phex do
  @moduledoc ~s"""
  A PHP serialized decoder and encoder.

  ## Installation
  The package can be installed by adding `phex` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
  [
    {:phex, "~> #{Mix.Project.config()[:version]}"}
  ]
  end
  ```

  ## Basic Usage
      iex> Phex.encode!(%{"age" => 42, "name" => "John Doe"})
      "a:2:{s:3:\\\"age\\\";i:42;s:4:\\\"name\\\";s:8:\\\"John Doe\\\";}"

      iex> Phex.decode!("a:2:{s:3:\\\"age\\\";i:42;s:4:\\\"name\\\";s:8:\\\"John Doe\\\";}")
      %{"age" => 42, "name" => "John Doe"}

  ## PHP arrays and key-collisions
  The way in which PHP handles array keys is a bit peculiar, the details can be found [here](http://www.phpinternalsbook.com/php5/hashtables/array_api.html#symtable-and-array-api).

  Phex mimics this an will cast values in the manner described [here](https://www.php.net/manual/en/language.types.array.php).

      iex> %{"1" => "a", 1.1 => "b"}
      ...> |> Phex.encode!()
      ...> |> Phex.decode!()
      ** (Phex.EncodeError) Duplicate key: 1

      iex> %{"1" => "1"}
      ...> |> Phex.encode!()
      ...> |> Phex.decode!()
      %{1 => "1"}

      iex> %{1.1 => "1"}
      ...> |> Phex.encode!()
      ...> |> Phex.decode!()
      %{1 => "1"}

      iex> %{nil => "1"}
      ...> |> Phex.encode!()
      ...> |> Phex.decode!()
      %{"" => "1"}

      iex> %{true => "1"}
      ...> |> Phex.encode!()
      ...> |> Phex.decode!()
      %{1 => "1"}

  """
  alias Phex.{Encode, Decode}

  @type key :: String.t() | integer()
  @type t :: nil | boolean() | number() | String.t() | array()
  @type array :: [{key, t()}]

  # @type decode_opts :: [{:arrays, :naive | :strict} | decode_opts()]
  @type decode_opts :: :naive | :strict

  # @type encode_opts :: [{:arrays, :naive | :strict} | encode_opts()]

  defmodule EncodeError do
    defexception [:message]
  end

  defmodule DecodeError do
    defexception [:message]
  end

  @doc ~S"""
  Creates a PHP-Serialized binary from a term.

  Like `encode/2` but raises a in case of errors.
  ## Examples
      iex> encode!(%{"Blue" => 2, "Pink" => 4})
      "a:2:{s:4:\"Blue\";i:2;s:4:\"Pink\";i:4;}"

      iex> Phex.encode!(%{"" => 2, nil => 4})
      ** (Phex.EncodeError) Duplicate key: ""
  """
  def encode!(term) do
    term
    |> Encode.encode()
    |> IO.iodata_to_binary()
  end

  @doc ~S"""
  Creates a PHP-Serialized binary from a term.
  ## Examples
      iex> encode(nil)
      {:ok, "N;"}

      iex> encode(true)
      {:ok, "b:1;"}

      iex> encode(9000)
      {:ok, "i:9000;"}

      iex> encode(3.14159265359)
      {:ok, "d:3.14159265359;"}

      iex> encode("Hello")
      {:ok, "s:5:\"Hello\";"}

      iex> encode(%{"Blue" => 2, "Pink" => 4})
      {:ok, "a:2:{s:4:\"Blue\";i:2;s:4:\"Pink\";i:4;}"}
  """
  def encode(term) do
    {:ok, encode!(term)}
  rescue
    e in EncodeError -> {:error, e.message}
  end

  @doc """
  Parses a PHP-Serialized value from a binary.

  Like `decode/2` but will unwrap the error tuple and raise
  in case of errors.
  ## Examples
      iex> Phex.decode!("a:0:{}")
      %{}

      iex> Phex.decode!("foo")
      ** (Phex.DecodeError) unable to decode
  """
  def decode!(binary, opt \\ :naive) when is_binary(binary) do
    case decode(binary, opt) do
      {:ok, result, _rest} -> result
      {:error, reason, _rest} -> raise DecodeError, message: reason
    end
  end

  @doc """
  Parses a PHP-Serialized value from a binary.
  ## Examples
      iex> decode("N;")
      {:ok, nil, ""}

      iex> decode("b:0;")
      {:ok, false, ""}

      iex> decode("i:-212;")
      {:ok, -212, ""}

      iex> decode("d:6.62607004;")
      {:ok, 6.62607004, ""}

      iex> decode("s:5:\\\"World\\\";")
      {:ok, "World", ""}

      iex> decode("a:2:{s:6:\\\"Bunker\\\";s:4:\\\"Blue\\\";s:7:\\\"Buscemi\\\";s:4:\\\"Pink\\\";}")
      {:ok, %{"Bunker" => "Blue", "Buscemi" => "Pink"}, ""}

      iex> decode("a:2:{s:6:\\\"Bunker\\\";s:4:\\\"Blue\\\";s:7:\\\"Buscemi\\\";s:4:\\\"Pink\\\";}", arrays: :strict)
      {:ok, [{"Bunker", "Blue"}, {"Buscemi", "Pink"}], ""}
  """
  # @spec decode(binary(), decode_opts()) ::
  #         {:ok, t(), binary()} | {:error, reason :: String.t(), binary()}
  def decode(binary, opt \\ :naive) do
    # dec_opts = Enum.into(opts, %{arrays: :naive})

    Decode.decode(binary, opt)
  end
end
