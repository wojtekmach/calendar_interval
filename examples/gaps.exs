defmodule Gaps do
  def gaps(interval, events) do
    gaps(interval, events, [])
  end

  defp gaps(interval, [head | tail], acc) do
    case CalendarInterval.split(interval, head) do
      {left_gap, ^head, right_gap} ->
        gaps(right_gap, tail, [left_gap | acc])

      {left_gap, ^head} ->
        Enum.reverse([left_gap | acc])

      {^head, right_gap} ->
        gaps(right_gap, tail, acc)
    end
  end

  defp gaps(right_gap, [], acc) do
    Enum.reverse([right_gap | acc])
  end

  def print(interval, events, gaps) do
    IO.puts("")
    IO.inspect interval, label: "interval"
    IO.inspect events, label: "  events"
    IO.inspect gaps, label: "    gaps", width: 200
  end
end

use CalendarInterval
interval = ~I"2018-01-01 00:00/03 23:59"
events = [~I"2018-01-01 09:00/10:00", ~I"2018-01-02 09:00/10:00"]
gaps = Gaps.gaps(interval, events)
^gaps = [~I"2018-01-01 00:00/08:59", ~I"2018-01-01 10:01/02 08:59", ~I"2018-01-02 10:01/03 23:59"]
Gaps.print(interval, events, gaps)

interval = ~I"2018-01-01 00:00/03 23:59"
events = [~I"2018-01-01 00:00/10:00", ~I"2018-01-02 09:00/10:00"]
gaps = Gaps.gaps(interval, events)
^gaps = [~I"2018-01-01 10:01/02 08:59", ~I"2018-01-02 10:01/03 23:59"]
Gaps.print(interval, events, gaps)

interval = ~I"2018-01-01 00:00/03 23:59"
events = [~I"2018-01-01 09:00/10:00", ~I"2018-01-03 09:00/23:59"]
gaps = Gaps.gaps(interval, events)
^gaps = [~I"2018-01-01 00:00/08:59", ~I"2018-01-01 10:01/03 08:59"]
Gaps.print(interval, events, gaps)
