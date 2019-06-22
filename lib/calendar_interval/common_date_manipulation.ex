defmodule CalendarInterval.CommonDateManipulation do
  defp precision_to_count_unit(:day), do: {24 * 60 * 60, :second}
  defp precision_to_count_unit(:hour), do: {60 * 60, :second}
  defp precision_to_count_unit(:minute), do: {60, :second}
  defp precision_to_count_unit(:second), do: {1, :second}

  defp precision_to_count_unit({:microsecond, exponent}) do
    {1, Enum.reduce(1..exponent, 1, fn _, acc -> acc * 10 end)}
  end

  @doc false
  def common_count(%{year: year1}, %{year: year2}, :year),
    do: year2 - year1 + 1

  def common_count(%{year: year1, month: month1}, %{year: year2, month: month2}, :month),
    do: month2 + year2 * 12 - month1 - year1 * 12 + 1

  def common_count(first, last, precision) do
    {count, unit} = precision_to_count_unit(precision)
    div(NaiveDateTime.diff(last, first, unit), count) + 1
  end

  @doc false
  def common_next_ndt(ndt, :year, step), do: update_in(ndt.year, &(&1 + step))

  def common_next_ndt(%NaiveDateTime{year: year, month: month} = ndt, :month, step) do
    {plus_year, month} = {div(month + step, 12), rem(month + step, 12)}

    if month == 0 do
      %{ndt | year: year + plus_year, month: 1}
    else
      %{ndt | year: year + plus_year, month: month}
    end
  end

  def common_next_ndt(ndt, precision, step) do
    {count, unit} = precision_to_count_unit(precision)
    NaiveDateTime.add(ndt, count * step, unit)
  end

  @doc false
  def common_prev_ndt(ndt, :year, step), do: update_in(ndt.year, &(&1 - step))

  # TODO: handle step != 1
  def common_prev_ndt(%NaiveDateTime{year: year, month: 1} = ndt, :month, step) do
    %{ndt | year: year - 1, month: 12 - step + 1}
  end

  # TODO: handle step != 1
  def common_prev_ndt(%NaiveDateTime{month: month} = ndt, :month, step) do
    %{ndt | month: month - step}
  end

  def common_prev_ndt(ndt, precision, step) do
    {count, unit} = precision_to_count_unit(precision)
    NaiveDateTime.add(ndt, -count * step, unit)
  end

  @doc false
  def common_truncate(ndt, :year), do: common_truncate(%{ndt | month: 1}, :month)
  def common_truncate(ndt, :month), do: common_truncate(%{ndt | day: 1}, :day)
  def common_truncate(ndt, :day), do: %{ndt | hour: 0, minute: 0, second: 0, microsecond: {0, 6}}
  def common_truncate(ndt, :hour), do: %{ndt | minute: 0, second: 0, microsecond: {0, 6}}
  def common_truncate(ndt, :minute), do: %{ndt | second: 0, microsecond: {0, 6}}
  def common_truncate(ndt, :second), do: %{ndt | microsecond: {0, 6}}
  def common_truncate(ndt, {:microsecond, 6}), do: ndt

  def common_truncate(%{microsecond: {microsecond, _}} = ndt, {:microsecond, precision}) do
    {1, n} = precision_to_count_unit({:microsecond, 6 - precision})
    %{ndt | microsecond: {div(microsecond, n) * n, 6}}
  end
end
