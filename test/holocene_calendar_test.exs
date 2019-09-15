defmodule GregorianCalendarIntervalTest do
  use ExUnit.Case
  use CalendarInterval
  alias CalendarInterval, as: I

  def convert_to_holocene(ndt) do
    year = ndt.year
    %{ndt | year: year + 10_000, calendar: CalendarInterval.Holocene}
  end

  test "parse!/1" do
    i = I.parse!("2018 CalendarInterval.Holocene")
    assert i.precision == :year

    assert i.first ==
             ~N"2018-01-01 00:00:00.000000"
             |> convert_to_holocene

    assert i.last ==
             ~N"2018-12-31 23:59:59.999999"
             |> convert_to_holocene

    i = I.parse!("2018-06-15 CalendarInterval.Holocene")
    assert i.precision == :day

    assert i.first ==
             ~N"2018-06-15 00:00:00.000000"
             |> convert_to_holocene

    assert i.last ==
             ~N"2018-06-15 23:59:59.999999"
             |> convert_to_holocene

    i = I.parse!("2018-06-15 10:20:30.123 CalendarInterval.Holocene")
    assert i.precision == {:microsecond, 3}

    assert i.first ==
             ~N"2018-06-15 10:20:30.123000"
             |> convert_to_holocene

    assert i.last ==
             ~N"2018-06-15 10:20:30.123999"
             |> convert_to_holocene

    i = I.parse!("2018-06-15 10:20:30.123456 CalendarInterval.Holocene")
    assert i.precision == {:microsecond, 6}

    assert i.first ==
             ~N"2018-06-15 10:20:30.123456"
             |> convert_to_holocene

    assert i.last ==
             ~N"2018-06-15 10:20:30.123456"
             |> convert_to_holocene

    i = I.parse!("2018-06-15/16 CalendarInterval.Holocene")
    assert i.precision == :day

    assert i.first ==
             ~N"2018-06-15 00:00:00.000000"
             |> convert_to_holocene

    assert i.last ==
             ~N"2018-06-16 23:59:59.999999"
             |> convert_to_holocene

    i = I.parse!("2018-01-01 00:00/03 23:59 CalendarInterval.Holocene")
    assert i.precision == :minute

    assert i.first ==
             ~N[2018-01-01 00:00:00.000000]
             |> convert_to_holocene

    assert i.last ==
             ~N[2018-01-03 23:59:59.999999]
             |> convert_to_holocene
  end

  test "next/1" do
    i = I.next(~I"2018-01 CalendarInterval.Holocene")
    assert i.precision == :month

    assert i.first ==
             ~N"2018-02-01 00:00:00.000000"
             |> convert_to_holocene

    assert i.last ==
             ~N"2018-02-28 23:59:59.999999"
             |> convert_to_holocene

    i = I.next(~I"2018-01/02 CalendarInterval.Holocene")
    assert i == ~I"2018-03/04 CalendarInterval.Holocene"
    assert i.precision == :month

    assert i.first ==
             ~N"2018-03-01 00:00:00.000000"
             |> convert_to_holocene

    assert i.last ==
             ~N"2018-04-30 23:59:59.999999"
             |> convert_to_holocene

    i = I.next(~I"2018-01/02 CalendarInterval.Holocene", 2)
    assert i == ~I"2018-05/06 CalendarInterval.Holocene"
    assert i.precision == :month

    assert i.first ==
             ~N"2018-05-01 00:00:00.000000"
             |> convert_to_holocene

    assert i.last ==
             ~N"2018-06-30 23:59:59.999999"
             |> convert_to_holocene
  end

  test "prev/1" do
    i = I.prev(~I"2018-01 CalendarInterval.Holocene")
    assert i.precision == :month

    assert i.first ==
             ~N"2017-12-01 00:00:00.000000"
             |> convert_to_holocene

    assert i.last ==
             ~N"2017-12-31 23:59:59.999999"
             |> convert_to_holocene

    i = I.prev(~I"2018-03/04 CalendarInterval.Holocene")
    assert i == ~I"2018-01/02 CalendarInterval.Holocene"
    assert i.precision == :month

    assert i.first ==
             ~N"2018-01-01 00:00:00.000000"
             |> convert_to_holocene

    assert i.last ==
             ~N"2018-02-28 23:59:59.999999"
             |> convert_to_holocene

    i = I.prev(~I"2018-05/06 CalendarInterval.Holocene", 2)
    assert i == ~I"2018-01/02 CalendarInterval.Holocene"
    assert i.precision == :month

    assert i.first ==
             ~N"2018-01-01 00:00:00.000000"
             |> convert_to_holocene

    assert i.last ==
             ~N"2018-02-28 23:59:59.999999"
             |> convert_to_holocene
  end

  test "enclosing/1" do
    interval = ~I"2018-02-03 10:20:30.123456 CalendarInterval.Holocene"

    i = I.enclosing(interval, {:microsecond, 3})

    assert i.first ==
             ~N"2018-02-03 10:20:30.123000"
             |> convert_to_holocene

    assert i.last ==
             ~N"2018-02-03 10:20:30.123999"
             |> convert_to_holocene

    i = I.enclosing(interval, :second)

    assert i.first ==
             ~N"2018-02-03 10:20:30.000000"
             |> convert_to_holocene

    assert i.last ==
             ~N"2018-02-03 10:20:30.999999"
             |> convert_to_holocene

    i = I.enclosing(interval, :minute)

    assert i.first ==
             ~N"2018-02-03 10:20:00.000000"
             |> convert_to_holocene

    assert i.last ==
             ~N"2018-02-03 10:20:59.999999"
             |> convert_to_holocene

    i = I.enclosing(interval, :hour)

    assert i.first ==
             ~N"2018-02-03 10:00:00.000000"
             |> convert_to_holocene

    assert i.last ==
             ~N"2018-02-03 10:59:59.999999"
             |> convert_to_holocene

    i = I.enclosing(interval, :day)

    assert i.first ==
             ~N"2018-02-03 00:00:00.000000"
             |> convert_to_holocene

    assert i.last ==
             ~N"2018-02-03 23:59:59.999999"
             |> convert_to_holocene

    i = I.enclosing(interval, :month)

    assert i.first ==
             ~N"2018-02-01 00:00:00.000000"
             |> convert_to_holocene

    assert i.last ==
             ~N"2018-02-28 23:59:59.999999"
             |> convert_to_holocene
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

    assert (~N"2018-01-01 09:00:00"
            |> Map.put(:calendar, CalendarInterval.Holocene)
            |> convert_to_holocene) in ~I"2018 CalendarInterval.Holocene"

    assert (~N"2018-12-31 23:59:59"
            |> Map.put(:calendar, CalendarInterval.Holocene)
            |> convert_to_holocene) in ~I"2018 CalendarInterval.Holocene"

    assert not ((~N"2019-01-01 01:01:01"
                 |> convert_to_holocene) in ~I"2018 CalendarInterval.Holocene")

    assert (~D"2018-01-01"
            |> Map.put(:calendar, CalendarInterval.Holocene)
            |> convert_to_holocene) in ~I"2018 CalendarInterval.Holocene"

    assert not ((~D"2019-01-01"
                 |> Map.put(:calendar, CalendarInterval.Holocene)
                 |> convert_to_holocene) in ~I"2018 CalendarInterval.Holocene")

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
