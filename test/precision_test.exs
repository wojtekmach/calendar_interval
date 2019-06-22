defmodule CalendarInterval.PrecisionTest do
  use ExUnit.Case
  alias CalendarInterval.Precision

  Code.require_file("quarter.exs", "test/support")

  describe "default state" do
    test "precisions" do
      expected = [
        :year,
        :month,
        :day,
        :hour,
        :minute,
        :second,
        {:microsecond, 1},
        {:microsecond, 2},
        {:microsecond, 3},
        {:microsecond, 4},
        {:microsecond, 5},
        {:microsecond, 6}
      ]

      assert expected == Precision.precisions()
    end

    test "default precisions are valid" do
      for precision <- Precision.precisions() do
        assert Precision.valid?(precision)
      end
    end

    test "compare" do
      indexed_precisions = Enum.with_index(Precision.precisions())

      for {precision, index} <- indexed_precisions do
        {before, [{current, _} | beyond]} =
          Enum.split_while(indexed_precisions, fn {_, i} -> i < index end)

        for {b, _} <- before do
          assert Precision.compare(precision, b) == :gt
        end

        assert Precision.compare(precision, current) == :eq

        for {b, _} <- beyond do
          assert Precision.compare(precision, b) == :lt
        end
      end
    end
  end

  describe "with additional precision" do
    setup do
      Application.put_env(:calendar_interval, :precisions_modifier, {Quarter, :register})

      on_exit(fn ->
        Application.delete_env(:calendar_interval, :precisions_modifier)
      end)
    end

    test "precisions" do
      expected = [
        :year,
        :quarter,
        :month,
        :day,
        :hour,
        :minute,
        :second,
        {:microsecond, 1},
        {:microsecond, 2},
        {:microsecond, 3},
        {:microsecond, 4},
        {:microsecond, 5},
        {:microsecond, 6}
      ]

      assert expected == Precision.precisions()
    end

    test "added precisions are valid" do
      assert Precision.valid?(:quarter)
    end

    test "compare" do
      precision = :quarter

      before = [:year]
      current = :quarter

      beyond = [
        :month,
        :day,
        :hour,
        :minute,
        :second,
        {:microsecond, 1},
        {:microsecond, 2},
        {:microsecond, 3},
        {:microsecond, 4},
        {:microsecond, 5},
        {:microsecond, 6}
      ]

      for {b, _} <- before do
        assert Precision.compare(precision, b) == :gt
      end

      assert Precision.compare(precision, current) == :eq

      for {b, _} <- beyond do
        assert Precision.compare(precision, b) == :lt
      end
    end

    test "parse quarter" do
      assert {:ok, :quarter, "2019-04-01 00:00:00.000000"} = Precision.parse("2019Q2")
    end

    test "other precisions can still be parsed" do
      assert {:ok, :year, "2019-01-01 00:00:00.000000"} = Precision.parse("2019")
      assert {:ok, :month, "2019-02-01 00:00:00.000000"} = Precision.parse("2019-02")
    end

    test "format quarter" do
      assert "2019Q2" = Precision.format(~N[2019-04-01 00:00:00], :quarter)
    end

    test "other precisions can still be formated" do
      assert "2019" = Precision.format(~N[2019-01-01 00:00:00], :year)
      assert "2019-02" = Precision.format(~N[2019-02-01 00:00:00], :month)
    end
  end
end
