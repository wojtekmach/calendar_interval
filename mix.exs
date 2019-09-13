defmodule CalendarInterval.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/wojtekmach/calendar_interval"

  def project() do
    [
      app: :calendar_interval,
      version: @version,
      elixir: "~> 1.4",
      start_permanent: Mix.env() == :prod,
      description: "Functions for working with calendar intervals",
      docs: docs(),
      package: package(),
      deps: deps()
    ]
  end

  defp package() do
    [
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs() do
    [
      extras: ["README.md"],
      main: "readme",
      source_url: "https://github.com/wojtekmach/calendar_interval",
      source_ref: "v#{@version}"
    ]
  end

  defp deps() do
    [
      {:ex_doc, github: "elixir-lang/ex_doc", only: :dev, runtime: false},

      # A source of alternative calendars for testing
      {:ex_cldr_calendars, "~> 1.1", only: [:dev, :test], optional: true},

      {:dialyxir, "~> 1.0-rc", only: :dev, runtime: false}
    ]
  end
end
