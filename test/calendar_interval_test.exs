defmodule CalendarIntervalTest do
  use ExUnit.Case
  use CalendarInterval
  doctest CalendarInterval

  test "parse!/1" do
    i = CalendarInterval.parse!("2018")
    assert i.precision == :year
    assert i.first == ~N"2018-01-01 00:00:00.000000"
    assert i.last == ~N"2018-12-31 23:59:59.999999"

    i = CalendarInterval.parse!("2018-06-15")
    assert i.precision == :day
    assert i.first == ~N"2018-06-15 00:00:00.000000"
    assert i.last == ~N"2018-06-15 23:59:59.999999"

    i = CalendarInterval.parse!("2018-06-15 10:20:30.123")
    assert i.precision == {:microsecond, 3}
    assert i.first == ~N"2018-06-15 10:20:30.123000"
    assert i.last == ~N"2018-06-15 10:20:30.123999"

    i = CalendarInterval.parse!("2018-06-15 10:20:30.123456")
    assert i.precision == {:microsecond, 6}
    assert i.first == ~N"2018-06-15 10:20:30.123456"
    assert i.last == ~N"2018-06-15 10:20:30.123456"

    i = CalendarInterval.parse!("2018-06-15/16")
    assert i.precision == :day
    assert i.first == ~N"2018-06-15 00:00:00.000000"
    assert i.last == ~N"2018-06-16 23:59:59.999999"
  end

  @table [
    "2018",
    "2018-01",
    "2018-12",
    "2018-01-01",
    "2018-12-31 23",
    "2018-12-31 23:59",
    "2018-12-31 23:59:59",
    "2018-12-31 23:59:59.000",
    "2018-12-31 23:59:59.123",
    "2018-12-31 23:59:59.999",
    "2018-12-31 23:59:59.999999",
    "2018/2019",
    "2018-01/02",
    "2018-01/2019-02",
    "2018-12-31 23:00:00/59:59",
  ]

  for s <- @table do
    test "to_string/1: #{s}" do
      assert CalendarInterval.to_string(CalendarInterval.parse!(unquote(s))) == unquote(s)
    end
  end

  test "next/1" do
    i = CalendarInterval.next(~I"2018-01")
    assert i.precision == :month
    assert i.first == ~N"2018-02-01 00:00:00.000000"
    assert i.last == ~N"2018-02-28 23:59:59.999999"

    i = CalendarInterval.next(~I"2018-01/02")
    assert i == ~I"2018-03"
    assert i.precision == :month
    assert i.first == ~N"2018-03-01 00:00:00.000000"
    assert i.last == ~N"2018-03-31 23:59:59.999999"
  end

  test "prev/1" do
    i = CalendarInterval.prev(~I"2018-01")
    assert i.precision == :month
    assert i.first == ~N"2017-12-01 00:00:00.000000"
    assert i.last == ~N"2017-12-31 23:59:59.999999"

    i = CalendarInterval.prev(~I"2017-04/06")
    assert i.precision == :month
    assert i.first == ~N"2017-03-01 00:00:00.000000"
    assert i.last == ~N"2017-03-31 23:59:59.999999"
  end

  test "enumerable" do
    assert Enum.to_list(~I"2018") == [~I"2018"]
    assert Enum.to_list(~I"2018/2019") == [~I"2018", ~I"2019"]

    assert ~I"2018-06" in ~I"2018-01/12"
    assert ~I"2019-01" not in ~I"2018-01/12"

    assert ~I"2018-01-01" in ~I"2018"
    assert ~I"2018-04-01" in ~I"2018-03/05"
    assert ~I"2019-01-01" not in ~I"2018"

    assert Enum.count(~I"2018-01/12") == 12
    assert Enum.count(~I"2018-01-01/12-31") == 365
    assert Enum.count(~I"2016-01-01/12-31") == 366
  end
end
