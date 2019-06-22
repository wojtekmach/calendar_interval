defmodule CalendarInterval.Precision do
  @moduledoc """
  Handle all the functionality CalendarIntervals use, which depends on the used precision.
  """
  @type precision() :: atom | {atom, scale :: term}

  @callback to_iso8601(String.t()) :: {:ok, precision, String.t()} | :nomatch
  @callback format(NaiveDateTime.t(), precision) :: String.t()
  @callback format_left_right(left :: String.t(), right :: String.t()) ::
              {:ok, String.t()} | :nomatch
  @callback precisions() :: [precision, ...]
  @callback count(first :: NaiveDateTime.t(), last :: NaiveDateTime.t(), precision) ::
              non_neg_integer()
  @callback prev_ndt(NaiveDateTime.t(), precision, pos_integer()) :: NaiveDateTime.t()
  @callback next_ndt(NaiveDateTime.t(), precision, pos_integer()) :: NaiveDateTime.t()
  @callback truncate(NaiveDateTime.t(), precision) :: NaiveDateTime.t()

  @doc "List all available precisions."
  @spec precisions() :: [precision]
  def precisions do
    Enum.map(available_precisions_mapping(), &elem(&1, 0))
  end

  @doc "Assert if a precision is currently registered."
  @spec valid?(precision) :: boolean
  def valid?(precision) do
    precision in precisions()
  end

  @doc "Compare precisions by their granularity"
  @spec compare(precision, precision) :: :lt | :eq | :gt
  def compare(left, right) when left == right, do: :eq

  def compare(left, right) do
    Enum.find_value(precisions(), fn
      ^left -> :lt
      ^right -> :gt
      _ -> false
    end)
  end

  @doc "Parse a string and try to determine the intended precision."
  @spec parse(String.t()) :: {:ok, precision, String.t()} | :error
  def parse(string) do
    result =
      Enum.find_value(available_precision_modules(), fn module ->
        case module.to_iso8601(string) do
          {:ok, precision, str} -> {:ok, precision, str}
          :nomatch -> false
        end
      end)

    result || :error
  end

  @doc "Format the given date using a specific precision."
  @spec format(NaiveDateTime.t(), precision) :: String.t()
  def format(ndt, precision) do
    module = module_for_precision(precision)
    module.format(ndt, precision)
  end

  @doc "Pack together left and right formatted values in a shorter version."
  @spec format_left_right(String.t(), String.t(), precision) :: String.t()
  def format_left_right(left, left, _) do
    left
  end

  def format_left_right(left, right) do
    available_precision_modules()
    |> Enum.reverse()
    |> Enum.find_value("#{left}/#{right}", fn module ->
      case module.format_left_right(left, right) do
        {:ok, str} -> str
        :nomatch -> false
      end
    end)
  end

  @doc "Count the number of elements in the range between first and last"
  @spec count(NaiveDateTime.t(), NaiveDateTime.t(), precision) :: non_neg_integer()
  def count(first, last, precision) do
    module = module_for_precision(precision)
    module.count(first, last, precision)
  end

  @doc "Go a number of steps back in time by the given precision."
  @spec prev_ndt(NaiveDateTime.t(), precision, non_neg_integer()) :: NaiveDateTime.t()
  def prev_ndt(ndt, _precision, 0), do: ndt

  def prev_ndt(ndt, precision, step) do
    module = module_for_precision(precision)
    module.prev_ndt(ndt, precision, step)
  end

  @doc "Go a number of steps forward in time by the given precision."
  @spec next_ndt(NaiveDateTime.t(), precision, non_neg_integer()) :: NaiveDateTime.t()
  def next_ndt(ndt, _precision, 0), do: ndt

  def next_ndt(ndt, precision, step) do
    module = module_for_precision(precision)
    module.next_ndt(ndt, precision, step)
  end

  @doc "Truncate the place in time by the given precision."
  @spec truncate(NaiveDateTime.t(), precision) :: NaiveDateTime.t()
  def truncate(ndt, precision) do
    module = module_for_precision(precision)
    module.truncate(ndt, precision)
  end

  # Helpers

  defp module_for_precision(precision) do
    case List.keyfind(available_precisions_mapping(), precision, 0) do
      nil -> raise("Tried to use precision #{precision}, which is no longer registered.")
      {_, module} -> module
    end
  end

  defp available_precisions_mapping do
    # These are defined below this module
    [:year, :month, :day, :hour, :minute, :second, :microsecond]
    |> Enum.flat_map(fn key ->
      module = module_name(key)
      Enum.map(module.precisions(), &{&1, module})
    end)
    |> maybe_add_precisions()
  end

  defp maybe_add_precisions(list) do
    maybe_add_precisions(list, Application.get_env(:calendar_interval, :precisions_modifier))
  end

  defp maybe_add_precisions(list, {m, f}) do
    apply(m, f, [list])
  end

  defp maybe_add_precisions(list, _), do: list

  defp available_precision_modules do
    available_precisions_mapping()
    |> Enum.map(&elem(&1, 1))
    |> Enum.uniq()
  end

  @doc false
  def module_name(precision_key) do
    module = String.capitalize(Atom.to_string(precision_key))
    Module.concat([__MODULE__, module])
  end
end

patterns = [
  {:year, 4, "-01-01 00:00:00.000000"},
  {:month, 7, "-01 00:00:00.000000"},
  {:day, 10, " 00:00:00.000000"},
  {:hour, 13, ":00:00.000000"},
  {:minute, 16, ":00.000000"},
  {:second, 19, ".000000"}
]

for {precision, bytes, rest} <- patterns do
  defmodule CalendarInterval.Precision.module_name(precision) do
    @behaviour CalendarInterval.Precision
    def to_iso8601(string) when byte_size(string) == unquote(bytes) do
      {:ok, unquote(precision), string <> unquote(rest)}
    end

    def to_iso8601(_), do: :nomatch

    def precisions, do: [unquote(precision)]

    def format(ndt, unquote(precision)) do
      String.slice(NaiveDateTime.to_string(ndt), 0, unquote(bytes))
    end

    def format_left_right(
          <<left::unquote(bytes + 1)-bytes>> <> left_rest,
          <<left::unquote(bytes + 1)-bytes>> <> right_rest
        ) do
      {:ok, left <> left_rest <> "/" <> right_rest}
    end

    def format_left_right(_, _), do: :nomatch

    defdelegate count(first, last, precision), to: CalendarInterval.CommonDateManipulation
    defdelegate prev_ndt(ndt, precision, step), to: CalendarInterval.CommonDateManipulation
    defdelegate next_ndt(ndt, precision, step), to: CalendarInterval.CommonDateManipulation
    defdelegate truncate(ndt, precision), to: CalendarInterval.CommonDateManipulation
  end
end

defmodule CalendarInterval.Precision.module_name(:microsecond) do
  @behaviour CalendarInterval.Precision

  @scales [
    {{:microsecond, 1}, 21, "00000"},
    {{:microsecond, 2}, 22, "0000"},
    {{:microsecond, 3}, 23, "000"},
    {{:microsecond, 4}, 24, "00"},
    {{:microsecond, 5}, 25, "0"},
    {{:microsecond, 6}, 26, ""}
  ]

  for {precision, bytes, rest} <- @scales do
    def to_iso8601(string) when byte_size(string) == unquote(bytes) do
      {:ok, unquote(precision), string <> unquote(rest)}
    end
  end

  def to_iso8601(_), do: :nomatch

  for {precision, bytes, _rest} <- @scales do
    def format(ndt, unquote(precision)) do
      String.slice(NaiveDateTime.to_string(ndt), 0, unquote(bytes))
    end
  end

  for {_precision, bytes, _rest} <- Enum.reverse(@scales) do
    def format_left_right(
          <<left::unquote(bytes + 1)-bytes>> <> left_rest,
          <<left::unquote(bytes + 1)-bytes>> <> right_rest
        ) do
      left <> left_rest <> "/" <> right_rest
    end
  end

  def format_left_right(_, _), do: :nomatch

  def precisions, do: unquote(Enum.map(@scales, &elem(&1, 0)))

  defdelegate count(first, last, precision), to: CalendarInterval.CommonDateManipulation
  defdelegate prev_ndt(ndt, precision, step), to: CalendarInterval.CommonDateManipulation
  defdelegate next_ndt(ndt, precision, step), to: CalendarInterval.CommonDateManipulation
  defdelegate truncate(ndt, precision), to: CalendarInterval.CommonDateManipulation
end
