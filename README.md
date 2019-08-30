# CalendarInterval

[![Build Status](https://travis-ci.org/wojtekmach/calendar_interval.svg?branch=master)](https://travis-ci.org/wojtekmach/calendar_interval)

Functions for working with calendar intervals.

Key ideas:
* Time is enumerable: "2018" is a collection of "2018-01/2018-12" months, "2018-01-01/2018-12-31" days etc
* Everything is an interval: "2018" is an interval of 1 year, or 12 months, or 365 days etc.
  A timestamp with microsecond precision is an interval 1 microsecond long
* Allen's Interval Algebra: formalism for relations between time intervals

## Examples

```elixir
use CalendarInterval

iex> ~I"2018-06".precision
:month

iex> CalendarInterval.next(~I"2018-12-31")
~I"2019-01-01"

iex> CalendarInterval.nest(~I"2018-06-15", :minute)
~I"2018-06-15 00:00/23:59"

iex> CalendarInterval.relation(~I"2018-01", ~I"2018-02/12")
:meets

iex> Enum.count(~I"2016-01-01/12-31")
366
```

## References

This library is heavily inspired by "Exploring Time" talk by Eric Evans [1] where
he mentioned the concept of "Countable Time" and introduced me to
"Allen's Interval Algebra" [2].

- [1] <https://www.youtube.com/watch?v=Zm95cYAtAa8>
- [2] <https://www.ics.uci.edu/~alspaugh/cls/shr/allen.html>

I've also given a talk about some of these ideas at Empex NYC 2018:
[video](https://www.youtube.com/watch?v=vUOA5GgYg9I),
[slides](https://speakerdeck.com/wojtekmach/recurrences-and-intervals).

## Installation

Add to `mix.exs`:

```elixir
def deps do
  [
    {:calendar_interval, "~> 0.2"}
  ]
end
```

## License

[Apache 2.0](./LICENSE.md)
