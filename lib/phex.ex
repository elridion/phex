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
      "s:5:\\\"Hello\\\";"

      iex> decode!("s:5:\\\"World\\\";")
      "World"

  ### Maps (PHP-Arrays)
      iex> encode!(%{"Blue" => 2, "Pink" => 4})
      "a:2:{s:4:\\\"Blue\\\";i:2;s:4:\\\"Pink\\\";i:4;}"

      iex> decode!("a:2:{s:6:\\\"Bunker\\\";s:4:\\\"Blue\\\";s:7:\\\"Buscemi\\\";s:4:\\\"Pink\\\";}")
      %{"Bunker" => "Blue", "Buscemi" => "Pink"}

      iex> decode!("a:2:{s:6:\\\"Bunker\\\";s:4:\\\"Blue\\\";s:7:\\\"Buscemi\\\";s:4:\\\"Pink\\\";}", arrays: :strict)
      [{"Bunker", "Blue"}, {"Buscemi", "Pink"}]
  """
  alias Phex.Encode

  @type key :: String.t() | integer()
  @type t :: nil | boolean() | number() | String.t() | array()
  @type array :: [{key, t()}]

  @type decode_opts :: [{:arrays, :naive | :strict} | decode_opts()]

  # @type encode_opts :: [{:arrays, :naive | :strict} | encode_opts()]

  defmodule EncodeError do
    defexception [:message]
  end

  defmodule DecodeError do
    defexception [:message]
  end

  def encode!(term) do
    term
    |> Encode.encode()
    |> IO.iodata_to_binary()
  end

  def encode(term) do
    {:ok, encode!(term)}
  rescue
    e in Phex.EncodeError -> {:error, e.message}
  end

  def decode!(binary, opt \\ :naive) when is_binary(binary) do
    case decode(binary, opt) do
      {:ok, result, _rest} -> result
      {:error, reason, _rest} -> raise DecodeError, message: reason
    end
  end

  # @spec decode(binary(), decode_opts()) ::
  #         {:ok, t(), binary()} | {:error, reason :: String.t(), binary()}
  def decode(binary, opt \\ :naive) do
    # dec_opts = Enum.into(opts, %{arrays: :naive})

    Phex.Decode.decode(binary, opt)
  end
end
