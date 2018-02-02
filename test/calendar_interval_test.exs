defmodule CalendarIntervalTest do
  use ExUnit.Case
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
end
