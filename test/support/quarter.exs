defmodule Quarter do
  @behaviour CalendarInterval.Precision

  @quarter_to_month %{
    "1" => "01",
    "2" => "04",
    "3" => "07",
    "4" => "10"
  }

  def to_iso8601(<<year::4-bytes, "Q", quarter::1-bytes>>)
      when quarter in ["1", "2", "3", "4"] do
    {:ok, :quarter, "#{year}-#{@quarter_to_month[quarter]}-01 00:00:00.000000"}
  end

  def to_iso8601(_), do: :nomatch

  def precisions, do: [:quarter]

  def count(first, last, :quarter) do
    div(CalendarInterval.CommonDateManipulation.count(first, last, :month), 3)
  end

  def format(ndt, :quarter) do
    ndt = truncate(ndt, :quarter)

    q =
      case ndt.month do
        1 -> 1
        4 -> 2
        7 -> 3
        10 -> 4
      end

    "#{ndt.year}Q#{q}"
  end

  def format_left_right(
        <<year_left::4-bytes, "Q", quarter_left::1-bytes>>,
        <<year_left::4-bytes, "Q", quarter_right::1-bytes>>
      )
      when quarter_left in ["1", "2", "3", "4"] and quarter_right in ["1", "2", "3", "4"] do
    {:ok, "#{year_left}Q#{quarter_left}/Q#{quarter_right}"}
  end

  def format_left_right(_, _), do: :nomatch

  def next_ndt(ndt, :quarter, _step) do
    ndt
    |> CalendarInterval.CommonDateManipulation.next_ndt(:month, 1)
    |> CalendarInterval.CommonDateManipulation.next_ndt(:month, 1)
    |> CalendarInterval.CommonDateManipulation.next_ndt(:month, 1)
  end

  def prev_ndt(ndt, :quarter, _step) do
    ndt
    |> CalendarInterval.CommonDateManipulation.prev_ndt(:month, 1)
    |> CalendarInterval.CommonDateManipulation.prev_ndt(:month, 1)
    |> CalendarInterval.CommonDateManipulation.prev_ndt(:month, 1)
  end

  def truncate(ndt, :quarter) do
    month = div(ndt.month - 1, 3) * 3 + 1
    CalendarInterval.CommonDateManipulation.truncate(%{ndt | month: month}, :month)
  end

  def register(list) do
    Enum.flat_map(list, fn
      {:year, _} = el -> [el, {:quarter, __MODULE__}]
      el -> [el]
    end)
  end
end
