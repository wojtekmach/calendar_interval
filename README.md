# CalendarInterval

Functions for working with calendar intervals.

See [`lib/calendar_interval.ex`](lib/calendar_stream.ex).

## Examples

    use CalendarInterval

    iex> ~I"2018-06".precision
    :month

    iex> CalendarInterval.next(~I"2018-12-31")
    ~I"2019-01-01"

    iex> CalendarInterval.nest(~I"2018-06-15", :minute)
    ~I"2018-06-15 00:00/23:59"

    iex> Enum.count(~I"2016-01-01/12-31")
    366

## Installation

Add to `mix.exs`:

```elixir
def deps do
  [
    {:calendar_interval, github: "wojtekmach/calendar_interval"
  ]
end
```

## License

[Apache 2.0](./LICENSE.md)
