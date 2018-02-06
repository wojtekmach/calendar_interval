defmodule CalendarIntervalTest do
  use ExUnit.Case
  use CalendarInterval
  doctest CalendarInterval
  alias CalendarInterval, as: I

  test "parse!/1" do
    i = I.parse!("2018")
    assert i.precision == :year
    assert i.first == ~N"2018-01-01 00:00:00.000000"
    assert i.last == ~N"2018-12-31 23:59:59.999999"

    i = I.parse!("2018-06-15")
    assert i.precision == :day
    assert i.first == ~N"2018-06-15 00:00:00.000000"
    assert i.last == ~N"2018-06-15 23:59:59.999999"

    i = I.parse!("2018-06-15 10:20:30.123")
    assert i.precision == {:microsecond, 3}
    assert i.first == ~N"2018-06-15 10:20:30.123000"
    assert i.last == ~N"2018-06-15 10:20:30.123999"

    i = I.parse!("2018-06-15 10:20:30.123456")
    assert i.precision == {:microsecond, 6}
    assert i.first == ~N"2018-06-15 10:20:30.123456"
    assert i.last == ~N"2018-06-15 10:20:30.123456"

    i = I.parse!("2018-06-15/16")
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
    "2018-12-31 23:00:00/59:59"
  ]

  for s <- @table do
    test "to_string/1: #{s}" do
      assert I.to_string(I.parse!(unquote(s))) == unquote(s)
    end
  end

  test "next/1" do
    i = I.next(~I"2018-01")
    assert i.precision == :month
    assert i.first == ~N"2018-02-01 00:00:00.000000"
    assert i.last == ~N"2018-02-28 23:59:59.999999"

    i = I.next(~I"2018-01/02")
    assert i == ~I"2018-03/04"
    assert i.precision == :month
    assert i.first == ~N"2018-03-01 00:00:00.000000"
    assert i.last == ~N"2018-04-30 23:59:59.999999"

    i = I.next(~I"2018-01/02", 2)
    assert i == ~I"2018-05/06"
    assert i.precision == :month
    assert i.first == ~N"2018-05-01 00:00:00.000000"
    assert i.last == ~N"2018-06-30 23:59:59.999999"
  end

  test "prev/1" do
    i = I.prev(~I"2018-01")
    assert i.precision == :month
    assert i.first == ~N"2017-12-01 00:00:00.000000"
    assert i.last == ~N"2017-12-31 23:59:59.999999"

    i = I.prev(~I"2018-03/04")
    assert i == ~I"2018-01/02"
    assert i.precision == :month
    assert i.first == ~N"2018-01-01 00:00:00.000000"
    assert i.last == ~N"2018-02-28 23:59:59.999999"

    i = I.prev(~I"2018-05/06", 2)
    assert i == ~I"2018-01/02"
    assert i.precision == :month
    assert i.first == ~N"2018-01-01 00:00:00.000000"
    assert i.last == ~N"2018-02-28 23:59:59.999999"
  end

  test "enclosing/1" do
    interval = ~I"2018-02-03 10:20:30.123456"

    i = I.enclosing(interval, {:microsecond, 3})
    assert i.first == ~N"2018-02-03 10:20:30.123000"
    assert i.last == ~N"2018-02-03 10:20:30.123999"

    i = I.enclosing(interval, :second)
    assert i.first == ~N"2018-02-03 10:20:30.000000"
    assert i.last == ~N"2018-02-03 10:20:30.999999"

    i = I.enclosing(interval, :minute)
    assert i.first == ~N"2018-02-03 10:20:00.000000"
    assert i.last == ~N"2018-02-03 10:20:59.999999"

    i = I.enclosing(interval, :hour)
    assert i.first == ~N"2018-02-03 10:00:00.000000"
    assert i.last == ~N"2018-02-03 10:59:59.999999"

    i = I.enclosing(interval, :day)
    assert i.first == ~N"2018-02-03 00:00:00.000000"
    assert i.last == ~N"2018-02-03 23:59:59.999999"

    i = I.enclosing(interval, :month)
    assert i.first == ~N"2018-02-01 00:00:00.000000"
    assert i.last == ~N"2018-02-28 23:59:59.999999"
  end

  test "enumerable" do
    assert Enum.to_list(~I"2018") == [~I"2018"]
    assert Enum.to_list(~I"2018/2019") == [~I"2018", ~I"2019"]

    assert ~I"2018-06" in ~I"2018-01/12"
    assert not (~I"2019-01" in ~I"2018-01/12")

    assert ~I"2018-01-01" in ~I"2018"
    assert ~I"2018-04-01" in ~I"2018-03/05"
    assert not (~I"2019-01-01" in ~I"2018")

    assert ~N"2018-01-01 09:00:00" in ~I"2018"
    assert ~N"2018-12-31 23:59:59" in ~I"2018"
    assert not (~N"2019-01-01 01:01:01" in ~I"2018")

    assert ~D"2018-01-01" in ~I"2018"
    assert not (~D"2019-01-01" in ~I"2018")

    assert Enum.count(~I"2018-01/12") == 12
    assert Enum.count(~I"2018-01-01/12-31") == 365
    assert Enum.count(~I"2016-01-01/12-31") == 366
  end

  test "relation" do
    import CalendarInterval, only: [relation: 2, sigil_I: 2]

    assert relation(~I"2018", ~I"2018") == :equal

    assert relation(~I"2017", ~I"2018") == :meets
    assert relation(~I"2018", ~I"2017") == :met_by

    assert relation(~I"2016", ~I"2018") == :preceds
    assert relation(~I"2018", ~I"2016") == :preceded_by

    assert relation(~I"2018", ~I"2018/2019") == :starts
    assert relation(~I"2018/2019", ~I"2018") == :started_by

    assert relation(~I"2019", ~I"2018/2019") == :finishes
    assert relation(~I"2018/2019", ~I"2019") == :finished_by

    assert relation(~I"2018/2019", ~I"2010/2020") == :during
    assert relation(~I"2010/2020", ~I"2018/2019") == :contains

    assert relation(~I"2000/2015", ~I"2010/2020") == :overlaps
    assert relation(~I"2010/2020", ~I"2000/2015") == :overlapped_by
  end
end
