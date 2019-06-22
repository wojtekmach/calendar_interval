defmodule CalendarInterval do
  @moduledoc """
  Functions for working with calendar intervals.
  """
  alias CalendarInterval.Precision

  defstruct [:first, :last, :precision]

  @type t() :: %CalendarInterval{
          first: NaiveDateTime.t(),
          last: NaiveDateTime.t(),
          precision: precision()
        }

  @type precision() :: CalendarInterval.Precision.precision()

  # Lowest possible precision
  # Elixir does not support a better precision in it's datetime structs to this
  # can be kept hardcoded.
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
  def new(%NaiveDateTime{} = naive_datetime, precision) do
    validate_precision(precision)
    first = Precision.truncate(naive_datetime, precision)
    last = first |> Precision.next_ndt(precision, 1) |> Precision.prev_ndt(@microsecond, 1)
    new(first, last, precision)
  end

  def new(%Date{} = date, precision) do
    validate_precision(precision)
    {:ok, ndt} = NaiveDateTime.new(date, ~T"00:00:00")
    new(ndt, precision)
  end

  defp new(%NaiveDateTime{} = first, %NaiveDateTime{} = last, precision) do
    validate_precision(precision)

    if NaiveDateTime.compare(first, last) in [:eq, :lt] do
      %CalendarInterval{first: first, last: last, precision: precision}
    else
      first = Precision.format(first, precision)
      last = Precision.format(last, precision)

      raise ArgumentError, """
      Cannot create interval from #{first} and #{last}, descending intervals are not supported.\
      """
    end
  end

  defp validate_precision(precision) do
    unless Precision.valid?(precision) do
      raise ArgumentError, """
      Cannot create interval with invalid precision #{inspect(precision)}. \
      Available are #{inspect(Precision.precisions())}.\
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
  def utc_now(precision \\ @microsecond) do
    validate_precision(precision)
    now = NaiveDateTime.utc_now()
    first = Precision.truncate(now, precision)
    last = Precision.next_ndt(first, precision, 1) |> Precision.prev_ndt(@microsecond, 1)
    new(first, last, precision)
  end

  @doc """
  Handles the `~I` sigil for intervals.

  ## Examples

      iex> ~I"2018-06".precision
      :month

  """
  def sigil_I(string, []) do
    parse!(string)
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
        {:ok, precision, string} = Precision.parse(string)
        new(NaiveDateTime.from_iso8601!(string), precision)

      [left, right] ->
        right = String.slice(left, 0, byte_size(left) - byte_size(right)) <> right
        right = parse!(right)
        left = parse!(left)
        new(left.first, right.last, left.precision)
    end
  end

  @doc false
  def count(%CalendarInterval{first: first, last: last, precision: precision}),
    do: Precision.count(first, last, precision)

  @doc """
  Returns string representation.

  ## Examples

      iex> CalendarInterval.to_string(~I"2018-06")
      "2018-06"

  """
  @spec to_string(t()) :: String.t()
  def to_string(%CalendarInterval{first: first, last: last, precision: precision}) do
    left = Precision.format(first, precision)
    right = Precision.format(last, precision)

    if left == right do
      left
    else
      Precision.format_left_right(left, right)
    end
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
      |> Precision.next_ndt(@microsecond, 1)
      |> Precision.next_ndt(precision, count * (step - 1))

    last =
      first
      |> Precision.next_ndt(precision, count)
      |> Precision.prev_ndt(@microsecond, 1)

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
      |> Precision.prev_ndt(precision, count * step)

    last =
      first
      |> Precision.next_ndt(precision, count)
      |> Precision.prev_ndt(@microsecond, 1)

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
  def nest(%CalendarInterval{precision: old_precision} = interval, new_precision) do
    validate_precision(new_precision)

    case Precision.compare(old_precision, new_precision) do
      :eq ->
        interval

      :lt ->
        %{interval | precision: new_precision}

      _ ->
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
    validate_precision(new_precision)

    case Precision.compare(old_precision, new_precision) do
      :eq ->
        interval

      :gt ->
        interval.first |> Precision.truncate(new_precision) |> new(new_precision)

      _ ->
        raise ArgumentError,
              "cannot enclose from #{inspect(old_precision)} to #{inspect(new_precision)}"
    end
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
    if intersection(i1, i2) != nil or Precision.next_ndt(i1.last, @microsecond, 1) == i2.first do
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

      interval2.first == Precision.next_ndt(interval1.last, @microsecond, 1) ->
        :meets

      interval2.last == Precision.prev_ndt(interval1.first, @microsecond, 1) ->
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

    def member?(interval, %Date{} = date) do
      {:ok, ndt} = NaiveDateTime.new(date, ~T"00:00:00")
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
