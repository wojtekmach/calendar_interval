defmodule GregorianCalendarIntervalTest do
  use ExUnit.Case
  use CalendarInterval
  alias CalendarInterval, as: I

  @doc """
  Handles the sigil ~H for naive date times in the Holocene calendar.
  """
  defmacro sigil_H({:<<>>, _, [string]}, _) do
    Macro.escape(
      string
      |> NaiveDateTime.from_iso8601!()
      |> NaiveDateTime.convert!(CalendarInterval.Holocene)
    )
  end

  test "parse!/1" do
    i = I.parse!("2018 CalendarInterval.Holocene")
    assert i.precision == :year
    assert i.first == ~H"2018-01-01 00:00:00.000000"
    assert i.last == ~H"2018-12-31 23:59:59.999999"

    i = I.parse!("2018-06-15 CalendarInterval.Holocene")
    assert i.precision == :day
    assert i.first == ~H"2018-06-15 00:00:00.000000"
    assert i.last == ~H"2018-06-15 23:59:59.999999"

    i = I.parse!("2018-06-15 10:20:30.123 CalendarInterval.Holocene")
    assert i.precision == {:microsecond, 3}
    assert i.first == ~H"2018-06-15 10:20:30.123000"
    assert i.last == ~H"2018-06-15 10:20:30.123999"

    i = I.parse!("2018-06-15 10:20:30.123456 CalendarInterval.Holocene")
    assert i.precision == {:microsecond, 6}
    assert i.first == ~H"2018-06-15 10:20:30.123456"
    assert i.last == ~H"2018-06-15 10:20:30.123456"

    i = I.parse!("2018-06-15/16 CalendarInterval.Holocene")
    assert i.precision == :day
    assert i.first == ~H"2018-06-15 00:00:00.000000"
    assert i.last == ~H"2018-06-16 23:59:59.999999"

    i = I.parse!("2018-01-01 00:00/03 23:59 CalendarInterval.Holocene")
    assert i.precision == :minute
    assert i.first == ~H[2018-01-01 00:00:00.000000]
    assert i.last == ~H[2018-01-03 23:59:59.999999]
  end

  test "next/1" do
    i = I.next(~I"2018-01 CalendarInterval.Holocene")
    assert i.precision == :month
    assert i.first == ~H"2018-02-01 00:00:00.000000"
    assert i.last == ~H"2018-02-28 23:59:59.999999"

    i = I.next(~I"2018-01/02 CalendarInterval.Holocene")
    assert i == ~I"2018-03/04 CalendarInterval.Holocene"
    assert i.precision == :month
    assert i.first == ~H"2018-03-01 00:00:00.000000"
    assert i.last == ~H"2018-04-30 23:59:59.999999"

    i = I.next(~I"2018-01/02 CalendarInterval.Holocene", 2)
    assert i == ~I"2018-05/06 CalendarInterval.Holocene"
    assert i.precision == :month
    assert i.first == ~H"2018-05-01 00:00:00.000000"
    assert i.last == ~H"2018-06-30 23:59:59.999999"
  end

  test "prev/1" do
    i = I.prev(~I"2018-01 CalendarInterval.Holocene")
    assert i.precision == :month
    assert i.first == ~H"2017-12-01 00:00:00.000000"
    assert i.last == ~H"2017-12-31 23:59:59.999999"

    i = I.prev(~I"2018-03/04 CalendarInterval.Holocene")
    assert i == ~I"2018-01/02 CalendarInterval.Holocene"
    assert i.precision == :month
    assert i.first == ~H"2018-01-01 00:00:00.000000"
    assert i.last == ~H"2018-02-28 23:59:59.999999"

    i = I.prev(~I"2018-05/06 CalendarInterval.Holocene", 2)
    assert i == ~I"2018-01/02 CalendarInterval.Holocene"
    assert i.precision == :month
    assert i.first == ~H"2018-01-01 00:00:00.000000"
    assert i.last == ~H"2018-02-28 23:59:59.999999"
  end

  test "enclosing/1" do
    interval = ~I"2018-02-03 10:20:30.123456 CalendarInterval.Holocene"

    i = I.enclosing(interval, {:microsecond, 3})
    assert i.first == ~H"2018-02-03 10:20:30.123000"
    assert i.last == ~H"2018-02-03 10:20:30.123999"

    i = I.enclosing(interval, :second)
    assert i.first == ~H"2018-02-03 10:20:30.000000"
    assert i.last == ~H"2018-02-03 10:20:30.999999"

    i = I.enclosing(interval, :minute)
    assert i.first == ~H"2018-02-03 10:20:00.000000"
    assert i.last == ~H"2018-02-03 10:20:59.999999"

    i = I.enclosing(interval, :hour)
    assert i.first == ~H"2018-02-03 10:00:00.000000"
    assert i.last == ~H"2018-02-03 10:59:59.999999"

    i = I.enclosing(interval, :day)
    assert i.first == ~H"2018-02-03 00:00:00.000000"
    assert i.last == ~H"2018-02-03 23:59:59.999999"

    i = I.enclosing(interval, :month)
    assert i.first == ~H"2018-02-01 00:00:00.000000"
    assert i.last == ~H"2018-02-28 23:59:59.999999"
  end

  test "enumerable" do
    assert Enum.to_list(~I"2018 CalendarInterval.Holocene") == [
             ~I"2018 CalendarInterval.Holocene"
           ]

    assert Enum.to_list(~I"2018/2019 CalendarInterval.Holocene") == [
             ~I"2018 CalendarInterval.Holocene",
             ~I"2019 CalendarInterval.Holocene"
           ]

    assert ~I"2018-06 CalendarInterval.Holocene" in ~I"2018-01/12 CalendarInterval.Holocene"
    assert not (~I"2019-01 CalendarInterval.Holocene" in ~I"2018-01/12 CalendarInterval.Holocene")

    assert ~I"2018-01-01 CalendarInterval.Holocene" in ~I"2018 CalendarInterval.Holocene"
    assert ~I"2018-04-01 CalendarInterval.Holocene" in ~I"2018-03/05 CalendarInterval.Holocene"
    assert not (~I"2019-01-01 CalendarInterval.Holocene" in ~I"2018 CalendarInterval.Holocene")

    assert ~H"2018-01-01 09:00:00" in ~I"2018 CalendarInterval.Holocene"

    assert ~H"2018-12-31 23:59:59" in ~I"2018 CalendarInterval.Holocene"

    refute ~H"2019-01-01 01:01:01" in ~I"2018 CalendarInterval.Holocene"

    assert NaiveDateTime.to_date(~H"2018-01-01 00:00:00") in ~I"2018 CalendarInterval.Holocene"
    refute NaiveDateTime.to_date(~H"2019-01-01 00:00:00") in ~I"2018 CalendarInterval.Holocene"

    assert Enum.count(~I"2018-01/12 CalendarInterval.Holocene") == 12
    assert Enum.count(~I"2018-01-01/12-31 CalendarInterval.Holocene") == 365
    assert Enum.count(~I"2016-01-01/12-31 CalendarInterval.Holocene") == 366

    interval = ~I"2018-01-01/31 CalendarInterval.Holocene"
    assert Enum.at(interval, 0) == Enum.at(Enum.to_list(interval), 0)
    assert Enum.at(interval, 1) == Enum.at(Enum.to_list(interval), 1)
  end

  test "relation" do
    import CalendarInterval, only: [relation: 2, sigil_I: 2]

    assert relation(~I"2018 CalendarInterval.Holocene", ~I"2018 CalendarInterval.Holocene") ==
             :equal

    assert relation(~I"2017 CalendarInterval.Holocene", ~I"2018 CalendarInterval.Holocene") ==
             :meets

    assert relation(~I"2018 CalendarInterval.Holocene", ~I"2017 CalendarInterval.Holocene") ==
             :met_by

    assert relation(~I"2016 CalendarInterval.Holocene", ~I"2018 CalendarInterval.Holocene") ==
             :preceds

    assert relation(~I"2018 CalendarInterval.Holocene", ~I"2016 CalendarInterval.Holocene") ==
             :preceded_by

    assert relation(~I"2018 CalendarInterval.Holocene", ~I"2018/2019 CalendarInterval.Holocene") ==
             :starts

    assert relation(~I"2018/2019 CalendarInterval.Holocene", ~I"2018 CalendarInterval.Holocene") ==
             :started_by

    assert relation(~I"2019 CalendarInterval.Holocene", ~I"2018/2019 CalendarInterval.Holocene") ==
             :finishes

    assert relation(~I"2018/2019 CalendarInterval.Holocene", ~I"2019 CalendarInterval.Holocene") ==
             :finished_by

    assert relation(
             ~I"2018/2019 CalendarInterval.Holocene",
             ~I"2010/2020 CalendarInterval.Holocene"
           ) ==
             :during

    assert relation(
             ~I"2010/2020 CalendarInterval.Holocene",
             ~I"2018/2019 CalendarInterval.Holocene"
           ) ==
             :contains

    assert relation(
             ~I"2000/2015 CalendarInterval.Holocene",
             ~I"2010/2020 CalendarInterval.Holocene"
           ) ==
             :overlaps

    assert relation(
             ~I"2010/2020 CalendarInterval.Holocene",
             ~I"2000/2015 CalendarInterval.Holocene"
           ) ==
             :overlapped_by
  end
end
