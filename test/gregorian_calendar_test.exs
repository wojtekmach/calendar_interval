defmodule GregorianCalendarIntervalTest do
  use ExUnit.Case
  use CalendarInterval
  alias Cldr.Calendar.Gregorian
  alias CalendarInterval, as: I

  test "parse!/1" do
    i = I.parse!("2018 Cldr.Calendar.Gregorian")
    assert i.precision == :year
    assert i.first == ~N"2018-01-01 00:00:00.000000" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2018-12-31 23:59:59.999999" |> Map.put(:calendar, Gregorian)

    i = I.parse!("2018-06-15 Cldr.Calendar.Gregorian")
    assert i.precision == :day

    assert i.first == ~N"2018-06-15 00:00:00.000000" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2018-06-15 23:59:59.999999" |> Map.put(:calendar, Gregorian)

    i = I.parse!("2018-06-15 10:20:30.123 Cldr.Calendar.Gregorian")
    assert i.precision == {:microsecond, 3}

    assert i.first == ~N"2018-06-15 10:20:30.123000" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2018-06-15 10:20:30.123999" |> Map.put(:calendar, Gregorian)

    i = I.parse!("2018-06-15 10:20:30.123456 Cldr.Calendar.Gregorian")
    assert i.precision == {:microsecond, 6}
    assert i.first == ~N"2018-06-15 10:20:30.123456" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2018-06-15 10:20:30.123456" |> Map.put(:calendar, Gregorian)

    i = I.parse!("2018-06-15/16 Cldr.Calendar.Gregorian")
    assert i.precision == :day
    assert i.first == ~N"2018-06-15 00:00:00.000000" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2018-06-16 23:59:59.999999" |> Map.put(:calendar, Gregorian)
  end

  test "next/1" do
    i = I.next(~I"2018-01 Cldr.Calendar.Gregorian")
    assert i.precision == :month
    assert i.first == ~N"2018-02-01 00:00:00.000000" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2018-02-28 23:59:59.999999" |> Map.put(:calendar, Gregorian)

    i = I.next(~I"2018-01/02 Cldr.Calendar.Gregorian")
    assert i == ~I"2018-03/04 Cldr.Calendar.Gregorian"
    assert i.precision == :month

    assert i.first == ~N"2018-03-01 00:00:00.000000" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2018-04-30 23:59:59.999999" |> Map.put(:calendar, Gregorian)

    i = I.next(~I"2018-01/02 Cldr.Calendar.Gregorian", 2)
    assert i == ~I"2018-05/06 Cldr.Calendar.Gregorian"
    assert i.precision == :month
    assert i.first == ~N"2018-05-01 00:00:00.000000" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2018-06-30 23:59:59.999999" |> Map.put(:calendar, Gregorian)
  end

  test "prev/1" do
    i = I.prev(~I"2018-01 Cldr.Calendar.Gregorian")
    assert i.precision == :month

    assert i.first == ~N"2017-12-01 00:00:00.000000" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2017-12-31 23:59:59.999999" |> Map.put(:calendar, Gregorian)

    i = I.prev(~I"2018-03/04 Cldr.Calendar.Gregorian")
    assert i == ~I"2018-01/02 Cldr.Calendar.Gregorian"
    assert i.precision == :month

    assert i.first == ~N"2018-01-01 00:00:00.000000" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2018-02-28 23:59:59.999999" |> Map.put(:calendar, Gregorian)

    i = I.prev(~I"2018-05/06 Cldr.Calendar.Gregorian", 2)
    assert i == ~I"2018-01/02 Cldr.Calendar.Gregorian"
    assert i.precision == :month

    assert i.first == ~N"2018-01-01 00:00:00.000000" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2018-02-28 23:59:59.999999" |> Map.put(:calendar, Gregorian)
  end

  test "enclosing/1" do
    interval = ~I"2018-02-03 10:20:30.123456 Cldr.Calendar.Gregorian"

    i = I.enclosing(interval, {:microsecond, 3})
    assert i.first == ~N"2018-02-03 10:20:30.123000" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2018-02-03 10:20:30.123999" |> Map.put(:calendar, Gregorian)

    i = I.enclosing(interval, :second)
    assert i.first == ~N"2018-02-03 10:20:30.000000" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2018-02-03 10:20:30.999999" |> Map.put(:calendar, Gregorian)

    i = I.enclosing(interval, :minute)
    assert i.first == ~N"2018-02-03 10:20:00.000000" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2018-02-03 10:20:59.999999" |> Map.put(:calendar, Gregorian)

    i = I.enclosing(interval, :hour)
    assert i.first == ~N"2018-02-03 10:00:00.000000" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2018-02-03 10:59:59.999999" |> Map.put(:calendar, Gregorian)

    i = I.enclosing(interval, :day)
    assert i.first == ~N"2018-02-03 00:00:00.000000" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2018-02-03 23:59:59.999999" |> Map.put(:calendar, Gregorian)

    i = I.enclosing(interval, :month)

    assert i.first == ~N"2018-02-01 00:00:00.000000" |> Map.put(:calendar, Gregorian)
    assert i.last == ~N"2018-02-28 23:59:59.999999" |> Map.put(:calendar, Gregorian)
  end

  test "enumerable" do
    assert Enum.to_list(~I"2018 Cldr.Calendar.Gregorian") == [~I"2018 Cldr.Calendar.Gregorian"]

    assert Enum.to_list(~I"2018/2019 Cldr.Calendar.Gregorian") == [
             ~I"2018 Cldr.Calendar.Gregorian",
             ~I"2019 Cldr.Calendar.Gregorian"
           ]

    assert ~I"2018-06 Cldr.Calendar.Gregorian" in ~I"2018-01/12 Cldr.Calendar.Gregorian"
    assert not (~I"2019-01 Cldr.Calendar.Gregorian" in ~I"2018-01/12 Cldr.Calendar.Gregorian")
    assert ~I"2018-01-01 Cldr.Calendar.Gregorian" in ~I"2018 Cldr.Calendar.Gregorian"
    assert ~I"2018-04-01 Cldr.Calendar.Gregorian" in ~I"2018-03/05 Cldr.Calendar.Gregorian"
    assert not (~I"2019-01-01 Cldr.Calendar.Gregorian" in ~I"2018 Cldr.Calendar.Gregorian")

    assert (~N"2018-01-01 09:00:00" |> Map.put(:calendar, Gregorian)) in ~I"2018 Cldr.Calendar.Gregorian"

    assert (~N"2018-12-31 23:59:59" |> Map.put(:calendar, Gregorian)) in ~I"2018 Cldr.Calendar.Gregorian"

    assert not ((~N"2019-01-01 01:01:01" |> Map.put(:calendar, Gregorian)) in ~I"2018 Cldr.Calendar.Gregorian")

    assert (~D"2018-01-01" |> Map.put(:calendar, Gregorian)) in ~I"2018 Cldr.Calendar.Gregorian"

    assert not ((~D"2019-01-01" |> Map.put(:calendar, Gregorian)) in ~I"2018 Cldr.Calendar.Gregorian")

    assert Enum.count(~I"2018-01/12 Cldr.Calendar.Gregorian") == 12
    assert Enum.count(~I"2018-01-01/12-31 Cldr.Calendar.Gregorian") == 365
    assert Enum.count(~I"2016-01-01/12-31 Cldr.Calendar.Gregorian") == 366

    interval = ~I"2018-01-01/31 Cldr.Calendar.Gregorian"
    assert Enum.at(interval, 0) == Enum.at(Enum.to_list(interval), 0)
    assert Enum.at(interval, 1) == Enum.at(Enum.to_list(interval), 1)
  end

  test "relation" do
    import CalendarInterval, only: [relation: 2, sigil_I: 2]

    assert relation(~I"2018 Cldr.Calendar.Gregorian", ~I"2018 Cldr.Calendar.Gregorian") == :equal

    assert relation(~I"2017 Cldr.Calendar.Gregorian", ~I"2018 Cldr.Calendar.Gregorian") == :meets
    assert relation(~I"2018 Cldr.Calendar.Gregorian", ~I"2017 Cldr.Calendar.Gregorian") == :met_by

    assert relation(~I"2016 Cldr.Calendar.Gregorian", ~I"2018 Cldr.Calendar.Gregorian") ==
             :preceds

    assert relation(~I"2018 Cldr.Calendar.Gregorian", ~I"2016 Cldr.Calendar.Gregorian") ==
             :preceded_by

    assert relation(~I"2018 Cldr.Calendar.Gregorian", ~I"2018/2019 Cldr.Calendar.Gregorian") ==
             :starts

    assert relation(~I"2018/2019 Cldr.Calendar.Gregorian", ~I"2018 Cldr.Calendar.Gregorian") ==
             :started_by

    assert relation(~I"2019 Cldr.Calendar.Gregorian", ~I"2018/2019 Cldr.Calendar.Gregorian") ==
             :finishes

    assert relation(~I"2018/2019 Cldr.Calendar.Gregorian", ~I"2019 Cldr.Calendar.Gregorian") ==
             :finished_by

    assert relation(~I"2018/2019 Cldr.Calendar.Gregorian", ~I"2010/2020 Cldr.Calendar.Gregorian") ==
             :during

    assert relation(~I"2010/2020 Cldr.Calendar.Gregorian", ~I"2018/2019 Cldr.Calendar.Gregorian") ==
             :contains

    assert relation(~I"2000/2015 Cldr.Calendar.Gregorian", ~I"2010/2020 Cldr.Calendar.Gregorian") ==
             :overlaps

    assert relation(~I"2010/2020 Cldr.Calendar.Gregorian", ~I"2000/2015 Cldr.Calendar.Gregorian") ==
             :overlapped_by
  end
end
