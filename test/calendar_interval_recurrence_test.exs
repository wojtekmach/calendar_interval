defmodule CalendarIntervalCalendarRecurrenceTest do
  use ExUnit.Case, async: true
  use CalendarInterval

  test "recurrence" do
    recurrence = CalendarRecurrence.new(start: ~I"2018-01-01", stop: {:until, ~I"2018-01-03"})
    assert Enum.to_list(recurrence) == [~I"2018-01-01", ~I"2018-01-02", ~I"2018-01-03"]
  end
end
