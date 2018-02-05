defmodule CalendarInterval do
  @moduledoc """
  Functions for working with calendar intervals.

  * Text representation functions: `parse!/1`, `to_string/1`, `sigil_I/2`
  * "Countable Time" [1] operations: `enclosing/2`, `nest/2`, `next/1`, `prev/1`
  * Set-like operations: `intersection/2`, `union/2`
  * Other functions: `new/2`, `utc_now/1`, `split/2`

  ## Examples

      use CalendarInterval

      iex> ~I"2018-06".precision
      :month

      iex> CalendarInterval.next(~I"2018-12-31")
      ~I"2019-01-01"

      iex> CalendarInterval.nest(~I"2018-06-15", :minute)
      ~I"2018-06-15 00:00/23:59"

      iex> Enum.count(~I"2016-01-01/12-31")
      366

  ## References

  This library is inspired by "Exploring Time" talk by Eric Evans [1] where
  he mentioned the concept of "Countable Time".

  [1] <https://www.youtube.com/watch?v=Zm95cYAtAa8>

  """

  defstruct [:first, :last, :precision]

  @type t() :: %CalendarInterval{
          first: NaiveDateTime.t(),
          last: NaiveDateTime.t(),
          precision: precision()
        }

  @type precision() :: :year | :month | :day | :hour | :minute | :second | {:microsecond, 1..6}

  @precisions [:year, :month, :day, :hour, :minute, :second] ++
                for(i <- 1..6, do: {:microsecond, i})

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

  @microsecond {:microsecond, 6}

  @typedoc """
  Relation between two intervals according to Allen's Interval Algebra.

                        |
      a preceds b       | aaaa
                        |       bbbb
      -------------------------------
                        |
      a meets b         | aaaa
                        |     bbbb
                        |
      -------------------------------
                        |
      a overlaps b      | aaaa
                        |   bbbb
                        |
      -------------------------------
                        |
      a finished by b   | aaaa
                        |   bb
                        |
      -------------------------------
                        |
      a contains b      | aaaaaa
                        |   bb
                        |
      -------------------------------
                        |
      a starts b        |  aa
                        |  bbbb
                        |
      -------------------------------
                        |
      a equals b        | aaaa
                        | bbbb
                        |
      -------------------------------
                        |
      a started by b    | aaaa
                        | bb
                        |
      -------------------------------
                        |
      a during b        |   aa
                        | bbbbbb
                        |
      -------------------------------
                        |
      a finishes b      |   aa
                        | bbbb
                        |
      -------------------------------
                        |
      a overlapped by b |   aaaa
                        | bbbb
                        |
      -------------------------------
                        |
      a met by b        |     aaaa
                        | bbbb
                        |
      -------------------------------
                        |
      a preceded by b   |       aaaa
                        | bbbb
                        |

  See: <https://www.ics.uci.edu/~alspaugh/cls/shr/allen.html>
  """
  @type relation() ::
   :equal |
   :meets |
   :met_by |
   :preceds |
   :preceded_by |
   :starts |
   :started_by |
   :finishes |
   :finished_by |
   :during |
   :contains |
   :overlaps |
   :overlapped_by

  defmacro __using__(_) do
    quote do
      import CalendarInterval, only: [sigil_I: 2]
    end
  end

  @doc """
  Returns an interval starting at given date truncated to `precision`.

  ## Examples

      iex> CalendarInterval.new(~N"2018-06-15 10:20:30.134", :minute)
      ~I"2018-06-15 10:20"

      iex> CalendarInterval.new(~D"2018-06-15", :minute)
      ~I"2018-06-15 00:00"

  """
  @spec new(NaiveDateTime.t() | Date.t(), precision()) :: t()
  def new(%NaiveDateTime{} = naive_datetime, precision) do
    first = truncate(naive_datetime, precision)
    last = first |> next_ndt(precision) |> prev_ndt({:microsecond, 6})
    %CalendarInterval{first: first, last: last, precision: precision}
  end

  def new(%Date{} = date, precision) do
    {:ok, ndt} = NaiveDateTime.new(date, ~T"00:00:00")
    new(ndt, precision)
  end

  @doc """
  Returns an interval for the current UTC time in given `precision`.

  ## Examples

      iex> CalendarInterval.utc_now(:month) in ~I"2018/2100"
      true

  """
  @spec utc_now(precision()) :: t()
  def utc_now(precision \\ {:microsecond, 6}) do
    now = NaiveDateTime.utc_now()
    first = truncate(now, precision)
    last = next_ndt(first, precision) |> prev_ndt({:microsecond, 6})
    %CalendarInterval{first: first, last: last, precision: precision}
  end

  @doc """
  Handles the `~I` sigil for intervals.

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

      iex> CalendarInterval.parse!("2018-06-01/30")
      ~I"2018-06-01/30"

  """
  @spec parse!(String.t()) :: t()
  def parse!(string) do
    case String.split(string, "/", trim: true) do
      [string] ->
        {ndt, precision} = do_parse!(string)
        new(ndt, precision)

      [left, right] ->
        right = String.slice(left, 0, byte_size(left) - byte_size(right)) <> right
        right = parse!(right)
        left = parse!(left)
        %CalendarInterval{first: left.first, last: right.last, precision: left.precision}
    end
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

  defp next_ndt(ndt, :year), do: update_in(ndt.year, &(&1 + 1))

  defp next_ndt(%NaiveDateTime{year: year, month: 12} = ndt, :month) do
    %{ndt | year: year + 1, month: 1}
  end

  defp next_ndt(%NaiveDateTime{month: month} = ndt, :month) do
    %{ndt | month: month + 1}
  end

  defp next_ndt(ndt, precision) do
    {count, unit} = precision_to_count_unit(precision)
    NaiveDateTime.add(ndt, count, unit)
  end

  defp prev_ndt(ndt, :year), do: update_in(ndt.year, &(&1 - 1))

  defp prev_ndt(%NaiveDateTime{year: year, month: 1} = ndt, :month) do
    %{ndt | year: year - 1, month: 12}
  end

  defp prev_ndt(%NaiveDateTime{month: month} = ndt, :month) do
    %{ndt | month: month - 1}
  end

  defp prev_ndt(ndt, precision) do
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
  def to_string(%CalendarInterval{first: first, last: last, precision: precision}) do
    left = format(first, precision)
    right = format(last, precision)

    if left == right do
      left
    else
      format_left_right(left, right)
    end
  end

  defp format_left_right(left, left) do
    left
  end

  for i <- Enum.reverse([5, 8, 11, 14, 17, 20, 22, 23, 24, 25, 26]) do
    defp format_left_right(
           <<left::unquote(i)-bytes>> <> left_rest,
           <<left::unquote(i)-bytes>> <> right_rest
         ) do
      left <> left_rest <> "/" <> right_rest
    end
  end

  defp format_left_right(left, right) do
    left <> "/" <> right
  end

  defp format(ndt, {:microsecond, 6}) do
    NaiveDateTime.to_string(ndt)
  end

  for {precision, bytes, _} <- @patterns do
    defp format(ndt, unquote(precision)) do
      NaiveDateTime.to_string(ndt)
      |> String.slice(0, unquote(bytes))
    end
  end

  @doc """
  Returns next interval.

  ## Examples

      iex> CalendarInterval.next(~I"2018-06-30")
      ~I"2018-07-01"

      iex> CalendarInterval.next(~I"2018-01/06")
      ~I"2018-07"

  """
  @spec next(t()) :: t()
  def next(%CalendarInterval{last: last, precision: precision}) do
    last |> next_ndt({:microsecond, 6}) |> new(precision)
  end

  @doc """
  Returns previous interval.

  ## Examples

      iex> CalendarInterval.prev(~I"2018-06-01")
      ~I"2018-05-31"

      iex> CalendarInterval.prev(~I"2018-09/12")
      ~I"2018-08"

  """
  @spec prev(t()) :: t()
  def prev(%CalendarInterval{first: first, precision: precision}) do
    first |> prev_ndt(precision) |> new(precision)
  end

  @doc """
  Returns an interval within given interval.

  ## Example

      iex> CalendarInterval.nest(~I"2018", :day)
      ~I"2018-01-01/12-31"

      iex> CalendarInterval.nest(~I"2018-06-15", :minute)
      ~I"2018-06-15 00:00/23:59"

      iex> CalendarInterval.nest(~I"2018-06-15", :year)
      ** (ArgumentError) cannot nest from :day to :year

  """
  @spec nest(t(), precision()) :: t()
  def nest(%CalendarInterval{precision: old_precision} = interval, new_precision) do
    if precision_index(new_precision) > precision_index(old_precision) do
      %{interval | precision: new_precision}
    else
      raise ArgumentError,
            "cannot nest from #{inspect(old_precision)} to #{inspect(new_precision)}"
    end
  end

  @doc """
  Returns interval that encloses given interval.

  ## Example

      iex> CalendarInterval.enclosing(~I"2018-05-01", :year)
      ~I"2018"

      iex> CalendarInterval.enclosing(~I"2018-06-15", :second)
      ** (ArgumentError) cannot enclose from :day to :second

  """
  @spec enclosing(t(), precision()) :: t()
  def enclosing(%CalendarInterval{precision: old_precision} = interval, new_precision) do
    if precision_index(new_precision) < precision_index(old_precision) do
      interval.first |> truncate(new_precision) |> new(new_precision)
    else
      raise ArgumentError,
            "cannot enclose from #{inspect(old_precision)} to #{inspect(new_precision)}"
    end
  end

  defp truncate(ndt, :year), do: truncate(%{ndt | month: 1}, :month)
  defp truncate(ndt, :month), do: truncate(%{ndt | day: 1}, :day)
  defp truncate(ndt, :day), do: %{ndt | hour: 0, minute: 0, second: 0, microsecond: {0, 6}}
  defp truncate(ndt, :hour), do: %{ndt | minute: 0, second: 0, microsecond: {0, 6}}
  defp truncate(ndt, :minute), do: %{ndt | second: 0, microsecond: {0, 6}}
  defp truncate(ndt, :second), do: %{ndt | microsecond: {0, 6}}
  defp truncate(ndt, {:microsecond, 6}), do: ndt

  defp truncate(%{microsecond: {microsecond, _}} = ndt, {:microsecond, precision}) do
    {1, n} = precision_to_count_unit({:microsecond, 6 - precision})
    %{ndt | microsecond: {div(microsecond, n) * n, 6}}
  end

  for {precision, index} <- Enum.with_index(@precisions) do
    defp precision_index(unquote(precision)), do: unquote(index)
  end

  @doc """
  Returns an intersection of `interval1` and `interval2` or `nil` if they don't overlap.

  Both intervals must have the same `precision`.

  ## Examples

      iex> CalendarInterval.intersection(~I"2018-01/04", ~I"2018-03/06")
      ~I"2018-03/04"
      iex> CalendarInterval.intersection(~I"2018-01/12", ~I"2018-02")
      ~I"2018-02"

      iex> CalendarInterval.intersection(~I"2018-01/02", ~I"2018-11/12")
      nil

  """
  @spec intersection(t(), t()) :: t() | nil
  def intersection(interval1, interval2)

  def intersection(%CalendarInterval{precision: p} = i1, %CalendarInterval{precision: p} = i2) do
    if lteq?(i1.first, i2.last) and gteq?(i1.last, i2.first) do
      first = max_ndt(i1.first, i2.first)
      last = min_ndt(i1.last, i2.last)
      %CalendarInterval{first: first, last: last, precision: p}
    else
      nil
    end
  end

  @doc """
  Splits interval by another interval.

  ## Examples

      iex> CalendarInterval.split(~I"2018-01/12", ~I"2018-04/05")
      {~I"2018-01/03", ~I"2018-04/05", ~I"2018-06/12"}

      iex> CalendarInterval.split(~I"2018-01/12", ~I"2018-01/02")
      {~I"2018-01/02", ~I"2018-03/12"}
      iex> CalendarInterval.split(~I"2018-01/12", ~I"2018-08/12")
      {~I"2018-01/07", ~I"2018-08/12"}

      iex> CalendarInterval.split(~I"2018-01/12", ~I"2019-01")
      ~I"2018-01/12"

  """
  @spec split(t(), t()) :: t() | {t(), t()} | {t(), t(), t()}
  def split(%{precision: p} = interval1, %{precision: p} = interval2) do
    case relation(interval2, interval1) do
      :during ->
        a = i(interval1.first, prev(interval2).last, p)
        b = i(interval2.first, interval2.last, p)
        c = i(next(interval2).first, interval1.last, p)
        {a, b, c}

      :starts ->
        a = i(interval1.first, interval2.last, p)
        b = i(next(interval2).first, interval1.last, p)
        {a, b}

      :finishes ->
        a = i(interval1.first, prev(interval2).last, p)
        b = i(interval2.first, interval2.last, p)
        {a, b}

      _ ->
        interval1
    end
  end

  defp i(first, last, precision) do
    %CalendarInterval{first: first, last: last, precision: precision}
  end

  @doc """
  Returns an union of `interval1` and `interval2` or `nil`.

  Both intervals must have the same `precision`.

  ## Examples

      iex> CalendarInterval.union(~I"2018-01/02", ~I"2018-01/04")
      ~I"2018-01/04"
      iex> CalendarInterval.union(~I"2018-01/11", ~I"2018-12")
      ~I"2018-01/12"

      iex> CalendarInterval.union(~I"2018-01/02", ~I"2018-04/05")
      nil

  """
  @spec union(t(), t()) :: t() | nil
  def union(interval1, interval2)

  def union(%CalendarInterval{precision: p} = i1, %CalendarInterval{precision: p} = i2) do
    if intersection(i1, i2) != nil or next_ndt(i1.last, {:microsecond, 6}) == i2.first do
      %CalendarInterval{first: i1.first, last: i2.last, precision: p}
    else
      nil
    end
  end

  defp lt?(ndt1, ndt2), do: NaiveDateTime.compare(ndt1, ndt2) == :lt

  defp gt?(ndt1, ndt2), do: NaiveDateTime.compare(ndt1, ndt2) == :gt

  defp lteq?(ndt1, ndt2), do: NaiveDateTime.compare(ndt1, ndt2) in [:lt, :eq]

  defp gteq?(ndt1, ndt2), do: NaiveDateTime.compare(ndt1, ndt2) in [:gt, :eq]

  defp min_ndt(ndt1, ndt2), do: if(lteq?(ndt1, ndt2), do: ndt1, else: ndt2)

  defp max_ndt(ndt1, ndt2), do: if(gteq?(ndt1, ndt2), do: ndt1, else: ndt2)

  @doc """
  Returns a [`relation`](`t:CalendarInterval.relation/0`) between `interval1` and `interval2`.

  ## Examples

      iex> CalendarInterval.relation(~I"2018-01/02", ~I"2018-06")
      :preceds

      iex> CalendarInterval.relation(~I"2018-01/02", ~I"2018-03")
      :meets

      iex> CalendarInterval.relation(~I"2018-02", ~I"2018-01/12")
      :during

  """
  @spec relation(t(), t()) :: relation()
  def relation(%{precision: p} = interval1, %{precision: p} = interval2) do
    cond do
      interval1 == interval2 -> :equal
      interval2.first == next_ndt(interval1.last, @microsecond) -> :meets
      interval2.last == prev_ndt(interval1.first, @microsecond) -> :met_by
      lt?(interval1.last, interval2.first) -> :preceds
      gt?(interval1.first, interval2.last) -> :preceded_by
      interval1.first == interval2.first and lt?(interval1.last, interval2.last) -> :starts
      interval1.first == interval2.first and gt?(interval1.last, interval2.last) -> :started_by
      interval1.last == interval2.last and gt?(interval1.first, interval2.first) -> :finishes
      interval1.last == interval2.last and lt?(interval1.first, interval2.first) -> :finished_by
      gt?(interval1.first, interval2.first) and lt?(interval1.last, interval2.last) -> :during
      lt?(interval1.first, interval2.first) and gt?(interval1.last, interval2.last) -> :contains
      lt?(interval1.first, interval2.first) and
        lt?(interval1.last, interval2.last) and
        gt?(interval1.last, interval2.first) -> :overlaps
      gt?(interval1.first, interval2.first) and
        gt?(interval1.last, interval2.last) and
        lt?(interval1.first, interval2.last) -> :overlapped_by
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

  defimpl Enumerable do
    def count(_), do: {:error, __MODULE__}

    def member?(%{first: first, last: last}, %CalendarInterval{
          first: other_first,
          last: other_last
        }) do
      {:ok,
       NaiveDateTime.compare(other_first, first) in [:eq, :gt] and
         NaiveDateTime.compare(other_last, last) in [:eq, :lt]}
    end

    def member?(%{first: first, last: last}, %NaiveDateTime{} = ndt) do
      {:ok,
       NaiveDateTime.compare(ndt, first) in [:eq, :gt] and
         NaiveDateTime.compare(ndt, last) in [:eq, :lt]}
    end

    def member?(interval, %Date{} = date) do
      {:ok, ndt} = NaiveDateTime.new(date, ~T"00:00:00")
      member?(interval, ndt)
    end

    def slice(_), do: {:error, __MODULE__}

    def reduce(interval, acc, fun) do
      current = CalendarInterval.new(interval.first, interval.precision)
      reduce(current, interval.last, interval.precision, acc, fun)
    end

    defp reduce(_current_interval, _last, _precision, {:halt, acc}, _fun) do
      {:halted, acc}
    end

    defp reduce(_current_interval, _last, _precision, {:suspend, acc}, _fun) do
      {:suspended, acc}
    end

    defp reduce(current_interval, last, precision, {:cont, acc}, fun) do
      if NaiveDateTime.compare(current_interval.first, last) == :lt do
        next = CalendarInterval.next(current_interval)
        reduce(next, last, precision, fun.(current_interval, acc), fun)
      else
        {:halt, acc}
      end
    end
  end
end
