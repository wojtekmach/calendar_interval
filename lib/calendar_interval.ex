defmodule CalendarInterval do
  @moduledoc """
  Functions for working with calendar intervals.
  """

  defstruct [:first, :last, :precision]

  @type t() :: %CalendarInterval{
          first: NaiveDateTime.t(),
          last: NaiveDateTime.t(),
          precision: precision()
        }

  @type precision() ::
          :year | :quarter | :month | :day | :hour | :minute | :second | {:microsecond, 1..6}

  @precisions [:year, :quarter, :month, :day, :hour, :minute, :second] ++
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

  @doc """
  Calendar callback that adds years and months to a naive datetime.

  `step` can be positive or negative.

  When streaming intervals, this is the callback that increments years
  and months. Incrementing other time precision is managed directly through
  `NaiveDateTime.add/3`.
  """
  @callback add(Calendar.naive_datetime(), precision(), step :: integer()) ::
              {Calendar.year(), Calendar.month(), Calendar.day()}

  @doc """
  Callback that returns the quarter of the year for a given year, month and day
  """
  @callback quarter_of_year(Calendar.year(), Calendar.month(), Calendar.day()) :: pos_integer()

  @doc """
  Callback that returns a Date.Range representing the first date and last
  date of a given year and quarter
  """
  @callback quarter(Calendar.year(), quarter :: 1..4) :: Date.Range.t()

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
          :equal
          | :meets
          | :met_by
          | :preceds
          | :preceded_by
          | :starts
          | :started_by
          | :finishes
          | :finished_by
          | :during
          | :contains
          | :overlaps
          | :overlapped_by

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
  def new(%NaiveDateTime{} = naive_datetime, precision) when precision in @precisions do
    first = truncate(naive_datetime, precision)
    last = first |> next_ndt(precision, 1) |> prev_ndt(@microsecond, 1)
    new(first, last, precision)
  end

  def new(%Date{} = date, precision) when precision in @precisions do
    {:ok, ndt} = NaiveDateTime.new(date, ~T"00:00:00")
    new(ndt, precision)
  end

  defp new(%NaiveDateTime{} = first, %NaiveDateTime{} = last, precision)
       when precision in @precisions do
    if NaiveDateTime.compare(first, last) in [:eq, :lt] do
      %CalendarInterval{first: first, last: last, precision: precision}
    else
      first = format(first, precision)
      last = format(last, precision)

      raise ArgumentError, """
      cannot create interval from #{first} and #{last}, descending intervals are not supported\
      """
    end
  end

  @doc """
  Returns an interval for the current UTC time in given `t:precision/0`.

  ## Examples

      iex> CalendarInterval.utc_now(:month) in ~I"2018/2100"
      true

  """
  @spec utc_now(precision()) :: t()
  def utc_now(precision \\ @microsecond) when precision in @precisions do
    now = NaiveDateTime.utc_now()
    first = truncate(now, precision)
    last = next_ndt(first, precision, 1) |> prev_ndt(@microsecond, 1)
    new(first, last, precision)
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
    [string, calendar] = parse_including_calendar(string)

    case String.split(string, "/", trim: true) do
      [string] ->
        {ndt, precision} = do_parse!(string, calendar)
        new(ndt, precision)

      [left, right] ->
        right = String.slice(left, 0, byte_size(left) - byte_size(right)) <> right
        right = parse!(right <> " " <> inspect(calendar))
        left = parse!(left <> " " <> inspect(calendar))
        new(left.first, right.last, left.precision)
    end
  end

  defp parse_including_calendar(string) do
    case String.split(string, " ", trim: true) do
      [string] ->
        [string, Calendar.ISO]

      [date, <<d::utf8, _rest::binary>> = time] when d in ?0..?9 ->
        [date <> " " <> time, Calendar.ISO]

      [date, <<d::utf8, _rest::binary>> = time, calendar] when d in ?0..?9 ->
        [date <> " " <> time, Module.concat([calendar])]

      [date, calendar] ->
        [date, Module.concat([calendar])]
    end
  end

  defp do_parse!(<<year::4-bytes, "-", q::utf8, quarter::utf8>>, Calendar.ISO = calendar)
       when q in [?q, ?Q] and quarter in ?1..?4 do
    year = String.to_integer(year)
    month = (quarter - ?0 - 1) * 3 + 1
    {:ok, ndt} = NaiveDateTime.new(year, month, 1, 0, 0, 0, {0, 6}, calendar)
    {ndt, :quarter}
  end

  defp do_parse!(<<year::4-bytes, "-", q::utf8, quarter::utf8>>, calendar)
       when q in [?q, ?Q] and quarter in ?1..?4 do
    quarter = quarter - ?0
    year = String.to_integer(year)
    %{first: date} = calendar.quarter(year, quarter)
    {:ok, ndt} = NaiveDateTime.new(date.year, date.month, date.day, 0, 0, 0, {0, 6}, calendar)
    {ndt, :quarter}
  end

  for {precision, bytes, rest} <- @patterns do
    defp do_parse!(<<_::unquote(bytes)-bytes>> = string, calendar) do
      do_parse!(string <> unquote(rest), calendar)
      |> put_elem(1, unquote(precision))
    end
  end

  defp do_parse!(<<_::26-bytes>> = string, calendar) do
    {NaiveDateTime.from_iso8601!(string, calendar), @microsecond}
  end

  # Year increment

  defp next_ndt(%NaiveDateTime{calendar: Calendar.ISO} = ndt, :year, step) do
    update_in(ndt.year, &(&1 + step))
  end

  defp next_ndt(%NaiveDateTime{calendar: calendar} = ndt, :year, step) do
    calendar.add(ndt, :year, step)
  end

  # Quarter increment

  defp next_ndt(%NaiveDateTime{calendar: Calendar.ISO} = ndt, :quarter, step) do
    next_ndt(ndt, :month, step * 3)
  end

  defp next_ndt(%NaiveDateTime{calendar: calendar} = ndt, :quarter, step) do
    calendar.add(ndt, :quarter, step)
  end

  # Month increment

  defp next_ndt(%NaiveDateTime{calendar: Calendar.ISO} = ndt, :month, step) do
    %{year: year, month: month} = ndt
    {plus_year, month} = {div(month + step, 12), rem(month + step, 12)}

    if month == 0 do
      %{ndt | year: year + plus_year, month: 1}
    else
      %{ndt | year: year + plus_year, month: month}
    end
  end

  defp next_ndt(%NaiveDateTime{calendar: calendar} = ndt, :month, step) do
    calendar.add(ndt, :month, step)
  end

  # All other increments can be done in terms of seconds or microseconds
  # Incremented through NaiveDateTime

  defp next_ndt(ndt, precision, step) do
    {count, unit} = precision_to_count_unit(precision)
    NaiveDateTime.add(ndt, count * step, unit)
  end

  defp prev_ndt(%NaiveDateTime{calendar: Calendar.ISO} = ndt, :year, step) do
    update_in(ndt.year, &(&1 - step))
  end

  defp prev_ndt(%NaiveDateTime{calendar: calendar} = ndt, :year, step) do
    calendar.add(ndt, :year, -step)
  end

  defp prev_ndt(%NaiveDateTime{calendar: Calendar.ISO} = ndt, :quarter, step) do
    prev_ndt(ndt, :month, step * 3)
  end

  defp prev_ndt(%NaiveDateTime{calendar: calendar} = ndt, :quarter, step) do
    calendar.add(ndt, :quarter, -step)
  end

  # TODO: handle step != 1
  defp prev_ndt(%NaiveDateTime{year: year, month: 1, calendar: Calendar.ISO} = ndt, :month, step) do
    %{ndt | year: year - 1, month: 12 - step + 1}
  end

  # TODO: handle step != 1
  defp prev_ndt(%NaiveDateTime{month: month, calendar: Calendar.ISO} = ndt, :month, step) do
    %{ndt | month: month - step}
  end

  defp prev_ndt(%NaiveDateTime{calendar: calendar} = ndt, :month, step) do
    calendar.add(ndt, :month, -step)
  end

  defp prev_ndt(ndt, precision, step) do
    {count, unit} = precision_to_count_unit(precision)
    NaiveDateTime.add(ndt, -count * step, unit)
  end

  defp precision_to_count_unit(:day), do: {24 * 60 * 60, :second}
  defp precision_to_count_unit(:hour), do: {60 * 60, :second}
  defp precision_to_count_unit(:minute), do: {60, :second}
  defp precision_to_count_unit(:second), do: {1, :second}

  defp precision_to_count_unit({:microsecond, exponent}) do
    {1, Enum.reduce(1..exponent, 1, fn _, acc -> acc * 10 end)}
  end

  @doc false
  def count(%CalendarInterval{first: %{year: year1}, last: %{year: year2}, precision: :year}),
    do: year2 - year1 + 1

  def count(%CalendarInterval{precision: :quarter} = interval),
    do: div(count(%CalendarInterval{interval | precision: :month}), 3)

  def count(%CalendarInterval{
        first: %{year: year1, month: month1},
        last: %{year: year2, month: month2},
        precision: :month
      }),
      do: month2 + year2 * 12 - month1 - year1 * 12 + 1

  def count(%CalendarInterval{first: first, last: last, precision: precision}) do
    {count, unit} = precision_to_count_unit(precision)
    div(NaiveDateTime.diff(last, first, unit), count) + 1
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
      left <> maybe_add_calendar(first)
    else
      format_left_right(left, right) <> maybe_add_calendar(first)
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

  defp format(ndt, @microsecond) do
    NaiveDateTime.to_string(ndt)
  end

  defp format(%{year: year, month: month, calendar: Calendar.ISO}, :quarter) do
    quarter = div(month - 1, 3) + 1
    Kernel.to_string(year) <> "-Q" <> Kernel.to_string(quarter)
  end

  defp format(%{year: year, month: month, day: day, calendar: calendar}, :quarter) do
    quarter = calendar.quarter_of_year(year, month, day)
    Kernel.to_string(year) <> "-Q" <> Kernel.to_string(quarter)
  end

  for {precision, bytes, _} <- @patterns do
    defp format(ndt, unquote(precision)) do
      NaiveDateTime.to_string(ndt)
      |> String.slice(0, unquote(bytes))
    end
  end

  defp maybe_add_calendar(%{calendar: Calendar.ISO}) do
    ""
  end

  defp maybe_add_calendar(%{calendar: calendar}) do
    " " <> Kernel.inspect(calendar)
  end

  @doc """
  Returns first element of the interval.

  ## Examples

      iex> CalendarInterval.first(~I"2018-01/12")
      ~I"2018-01"

      iex> CalendarInterval.first(~I"2018-01")
      ~I"2018-01"

  """
  @spec first(t()) :: t()
  def first(%CalendarInterval{first: first, precision: precision}) do
    new(first, precision)
  end

  @doc """
  Returns last element of the interval.

  ## Examples

      iex> CalendarInterval.last(~I"2018-01/12")
      ~I"2018-12"

      iex> CalendarInterval.last(~I"2018-01")
      ~I"2018-01"

  """
  @spec last(t()) :: t()
  def last(%CalendarInterval{last: last, precision: precision}) do
    new(last, precision)
  end

  @doc """
  Returns next interval.

  ## Examples

      iex> CalendarInterval.next(~I"2018-06-30")
      ~I"2018-07-01"
      iex> CalendarInterval.next(~I"2018-06-30 09:00", 80)
      ~I"2018-06-30 10:20"

      iex> CalendarInterval.next(~I"2018-01/06")
      ~I"2018-07/12"
      iex> CalendarInterval.next(~I"2018-01/02", 2)
      ~I"2018-05/06"

  """
  @spec next(t(), step :: integer()) :: t()
  def next(interval, step \\ 1)

  def next(interval, 0) do
    interval
  end

  def next(%CalendarInterval{last: last, precision: precision} = interval, step) when step > 0 do
    count = count(interval)

    first =
      last
      |> next_ndt(@microsecond, 1)
      |> next_ndt(precision, count * (step - 1))

    last =
      first
      |> next_ndt(precision, count)
      |> prev_ndt(@microsecond, 1)

    new(first, last, precision)
  end

  @doc """
  Returns previous interval.

  ## Examples

      iex> CalendarInterval.prev(~I"2018-06-01")
      ~I"2018-05-31"
      iex> CalendarInterval.prev(~I"2018-06-01 01:00", 80)
      ~I"2018-05-31 23:40"

      iex> CalendarInterval.prev(~I"2018-07/12")
      ~I"2018-01/06"
      iex> CalendarInterval.prev(~I"2018-05/06", 2)
      ~I"2018-01/02"

  """
  @spec prev(t(), step :: integer()) :: t()
  def prev(interval, step \\ 1)

  def prev(interval, 0) do
    interval
  end

  def prev(%CalendarInterval{first: first, precision: precision} = interval, step)
      when step >= 0 do
    count = count(interval)

    first =
      first
      |> prev_ndt(precision, count * step)

    last =
      first
      |> next_ndt(precision, count)
      |> prev_ndt(@microsecond, 1)

    new(first, last, precision)
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
  def nest(%CalendarInterval{precision: old_precision} = interval, new_precision)
      when new_precision in @precisions do
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
  def enclosing(%CalendarInterval{precision: old_precision} = interval, new_precision)
      when new_precision in @precisions do
    if precision_index(new_precision) < precision_index(old_precision) do
      interval.first |> truncate(new_precision) |> new(new_precision)
    else
      raise ArgumentError,
            "cannot enclose from #{inspect(old_precision)} to #{inspect(new_precision)}"
    end
  end

  defp truncate(ndt, :year), do: truncate(%{ndt | month: 1}, :month)
  defp truncate(ndt, :quarter), do: truncate(%{ndt | day: 1}, :day)
  defp truncate(ndt, :month), do: truncate(%{ndt | day: 1}, :day)
  defp truncate(ndt, :day), do: %{ndt | hour: 0, minute: 0, second: 0, microsecond: {0, 6}}
  defp truncate(ndt, :hour), do: %{ndt | minute: 0, second: 0, microsecond: {0, 6}}
  defp truncate(ndt, :minute), do: %{ndt | second: 0, microsecond: {0, 6}}
  defp truncate(ndt, :second), do: %{ndt | microsecond: {0, 6}}
  defp truncate(ndt, @microsecond), do: ndt

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
      new(first, last, p)
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
        a = new(interval1.first, prev(interval2).last, p)
        b = new(interval2.first, interval2.last, p)
        c = new(next(interval2).first, interval1.last, p)
        {a, b, c}

      :starts ->
        a = new(interval1.first, interval2.last, p)
        b = new(next(interval2).first, interval1.last, p)
        {a, b}

      :finishes ->
        a = new(interval1.first, prev(interval2).last, p)
        b = new(interval2.first, interval2.last, p)
        {a, b}

      _ ->
        interval1
    end
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
    if intersection(i1, i2) != nil or next_ndt(i1.last, @microsecond, 1) == i2.first do
      new(i1.first, i2.last, p)
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
      interval1 == interval2 ->
        :equal

      interval2.first == next_ndt(interval1.last, @microsecond, 1) ->
        :meets

      interval2.last == prev_ndt(interval1.first, @microsecond, 1) ->
        :met_by

      lt?(interval1.last, interval2.first) ->
        :preceds

      gt?(interval1.first, interval2.last) ->
        :preceded_by

      interval1.first == interval2.first and lt?(interval1.last, interval2.last) ->
        :starts

      interval1.first == interval2.first and gt?(interval1.last, interval2.last) ->
        :started_by

      interval1.last == interval2.last and gt?(interval1.first, interval2.first) ->
        :finishes

      interval1.last == interval2.last and lt?(interval1.first, interval2.first) ->
        :finished_by

      gt?(interval1.first, interval2.first) and lt?(interval1.last, interval2.last) ->
        :during

      lt?(interval1.first, interval2.first) and gt?(interval1.last, interval2.last) ->
        :contains

      lt?(interval1.first, interval2.first) and lt?(interval1.last, interval2.last) and
          gt?(interval1.last, interval2.first) ->
        :overlaps

      gt?(interval1.first, interval2.first) and gt?(interval1.last, interval2.last) and
          lt?(interval1.first, interval2.last) ->
        :overlapped_by
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
    def count(interval) do
      {:ok, CalendarInterval.count(interval)}
    end

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

    def member?(interval, %Date{calendar: Calendar.ISO} = date) do
      {:ok, ndt} = NaiveDateTime.new(date, ~T"00:00:00")
      member?(interval, ndt)
    end

    def member?(interval, %Date{calendar: calendar} = date) do
      {:ok, ndt} = NaiveDateTime.new(date, ~T"00:00:00" |> Map.put(:calendar, calendar))
      member?(interval, ndt)
    end

    def slice(interval) do
      {:ok, CalendarInterval.count(interval), &slice(interval, &1 + 1, &2)}
    end

    defp slice(first, start, count) do
      interval =
        CalendarInterval.new(first.first, first.precision)
        |> CalendarInterval.next(start - 1)

      slice(interval, count)
    end

    defp slice(current, 1), do: [current]

    defp slice(current, remaining) do
      [current | slice(CalendarInterval.next(current), remaining - 1)]
    end

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
