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

  @doc """
  Parses a string into an interval.

  ## Examples

      iex> CalendarInterval.parse!("2018-06-30")
      %CalendarInterval{first: ~N[2018-06-30 00:00:00.000000], last: ~N[2018-06-30 23:59:59.999999], precision: :day}

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

  defp next(ndt, precision) do
    {count, unit} = precision_to_count_unit(precision)
    NaiveDateTime.add(ndt, count, unit)
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
end
