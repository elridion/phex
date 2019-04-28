defmodule Phex.MixProject do
  use Mix.Project

  @version "0.2.0"

  def project do
    [
      app: :phex,
      version: @version,
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.20", only: :dev}
    ]
  end

  defp description() do
    "A PHP serialized decoder and encoder."
  end

  defp docs do
    [
      main: "Phex",
      canonical: "http://hexdocs.pm/phex",
      # logo: "guides/images/e.png",
      source_url: "https://github.com/elridion/phex"
    ]
  end

  defp package() do
    [
      maintainers: ["Hans Gödeke"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["GNU General Public License v3.0"],
      links: %{
        "GitHub" => "https://github.com/elridion/phex"
      }
    ]
  end
end
