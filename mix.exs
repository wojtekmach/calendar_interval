defmodule CalendarInterval.MixProject do
  use Mix.Project

  @version "0.1.0-dev"

  def project do
    [
      app: :calendar_interval,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      docs: docs(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs() do
    [
      main: "CalendarInterval",
      source_url: "https://github.com/wojtekmach/calendar_interval",
      source_ref: "v#{@version}"
    ]
  end

  defp deps do
    [
      {:ex_doc, github: "elixir-lang/ex_doc", only: :dev}
    ]
  end
end
