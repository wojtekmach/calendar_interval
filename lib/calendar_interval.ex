defmodule CalendarInterval do
  defstruct [:first, :last, :precision]

  @type t() :: %CalendarInterval{
          first: NaiveDateTime.t(),
          last: NaiveDateTime.t(),
          precision: precision()
        }

  @type precision() :: :year | :month | :day | :hour | :minute | :second

  @patterns [
    {:year, 4, "-01-01 00:00:00"},
    {:month, 7, "-01 00:00:00"},
    {:day, 10, " 00:00:00"},
    {:hour, 13, ":00:00"},
    {:minute, 16, ":00"}
  ]

  @doc """
  Parses a string into an interval.

  ## Examples

      iex> CalendarInterval.parse!("2018-06-30")
      %CalendarInterval{first: ~N[2018-06-30 00:00:00], last: ~N[2018-06-30 23:59:59], precision: :day}

  """
  @spec parse!(String.t()) :: t()
  def parse!(string) do
    {ndt, precision} = do_parse!(string)
    last = next(ndt, precision) |> prev(:second)
    %CalendarInterval{first: ndt, last: last, precision: precision}
  end

  for {precision, bytes, rest} <- @patterns do
    defp do_parse!(<<_::unquote(bytes)-bytes>> = string) do
      do_parse!(string <> unquote(rest))
      |> put_elem(1, unquote(precision))
    end
  end

  defp do_parse!(string) do
    ndt = NaiveDateTime.from_iso8601!(string)
    {ndt, :second}
  end

  defp next(ndt, :year), do: update_in(ndt.year, & &1 + 1)
  defp next(ndt, :day), do: NaiveDateTime.add(ndt, 24 * 60 * 60, :second)

  defp prev(ndt, :second) do
    NaiveDateTime.add(ndt, -1, :second)
  end
end
