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
  end

  test "prev/1" do
    i = CalendarInterval.prev(~I"2018-01")
    assert i.precision == :month
    assert i.first == ~N"2017-12-01 00:00:00.000000"
    assert i.last == ~N"2017-12-31 23:59:59.999999"
  end
end
