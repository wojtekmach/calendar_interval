defmodule CalendarInterval do
  defstruct [:first, :last, :precision]

  @type t() :: %CalendarInterval{
          first: NaiveDateTime.t(),
          last: NaiveDateTime.t(),
          precision: precision()
        }

  @type precision() :: :year | :month | :day | :hour | :minute | :second | {:microsecond, 1..6}

  @patterns [
    {:year, 4, "-01-01 00:00:00.000000"},
    {:month, 7, "-01 00:00:00.000000"},
    {:day, 10, " 00:00:00.000000"},
    {:hour, 13, ":00:00.000000"},
    {:minute, 16, ":00.000000"},
    {:second, 19, ".000000"},
    {{:microsecond, 1}, 21, "00000"},
    {{:microsecond, 2}, 22, "0000"},
    {{:microsecond, 3}, 23, "000"},
    {{:microsecond, 4}, 24, "00"},
    {{:microsecond, 5}, 25, "0"}
  ]

  defmacro __using__(_) do
    quote do
      import CalendarInterval, only: [sigil_I: 2]
    end
  end

  @doc """
  Handles the `~I` for intervals.

  ## Examples

      iex> ~I"2018-06".precision
      :month

  """
  defmacro sigil_I({:<<>>, _, [string]}, []) do
    Macro.escape(parse!(string))
  end

  @doc """
  Parses a string into an interval.

  ## Examples

      iex> CalendarInterval.parse!("2018-06-30")
      ~I"2018-06-30"

  """
  @spec parse!(String.t()) :: t()
  def parse!(string) do
    {ndt, precision} = do_parse!(string)
    last = next(ndt, precision) |> prev({:microsecond, 6})
    %CalendarInterval{first: ndt, last: last, precision: precision}
  end

  for {precision, bytes, rest} <- @patterns do
    defp do_parse!(<<_::unquote(bytes)-bytes>> = string) do
      do_parse!(string <> unquote(rest))
      |> put_elem(1, unquote(precision))
    end
  end

  defp do_parse!(<<_::26-bytes>> = string) do
    {NaiveDateTime.from_iso8601!(string), {:microsecond, 6}}
  end

  defp next(ndt, :year), do: update_in(ndt.year, &(&1 + 1))

  defp next(%NaiveDateTime{year: year, month: 12} = ndt, :month) do
    %{ndt | year: year + 1, month: 1}
  end
  defp next(%NaiveDateTime{month: month} = ndt, :month) do
    %{ndt | month: month + 1}
  end

  defp next(ndt, precision) do
    {count, unit} = precision_to_count_unit(precision)
    NaiveDateTime.add(ndt, count, unit)
  end

  defp prev(ndt, :year), do: update_in(ndt.year, & &1 - 1)

  defp prev(%NaiveDateTime{year: year, month: 1} = ndt, :month) do
    %{ndt | year: year - 1, month: 12}
  end
  defp prev(%NaiveDateTime{month: month} = ndt, :month) do
    %{ndt | month: month - 1}
  end

  defp prev(ndt, precision) do
    {count, unit} = precision_to_count_unit(precision)
    NaiveDateTime.add(ndt, -count, unit)
  end

  defp precision_to_count_unit(:day), do: {24 * 60 * 60, :second}
  defp precision_to_count_unit(:hour), do: {60 * 60, :second}
  defp precision_to_count_unit(:minute), do: {60, :second}
  defp precision_to_count_unit(:second), do: {1, :second}

  defp precision_to_count_unit({:microsecond, exponent}) do
    {1, Enum.reduce(1..exponent, 1, fn _, acc -> acc * 10 end)}
  end

  @doc """
  Returns string representation.

  ## Examples

      iex> CalendarInterval.to_string(~I"2018-06")
      "2018-06"

  """
  @spec to_string(t()) :: String.t()
  def to_string(interval)

  def to_string(%CalendarInterval{first: first, last: _last, precision: {:microsecond, 6}}) do
    NaiveDateTime.to_string(first)
  end

  for {precision, bytes, _} <- @patterns do
    def to_string(%CalendarInterval{first: first, last: _last, precision: unquote(precision)}) do
      NaiveDateTime.to_string(first)
      |> String.slice(0, unquote(bytes))
    end
  end

  defimpl String.Chars do
    defdelegate to_string(interval), to: CalendarInterval
  end

  defimpl Inspect do
    def inspect(interval, _) do
      "~I\"" <> CalendarInterval.to_string(interval) <> "\""
    end
  end
end
