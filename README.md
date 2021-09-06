# Teleplug

Teleplug is a dead simple opentelemetry-instrumented plug.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `teleplug` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:teleplug, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/teleplug](https://hexdocs.pm/teleplug).

## Use

In your pipeline(`router.ex` or `endpoint.ex`) add

```
plug TelePlug
```

or

```
plug TelePlug, service_name: "my_name"
```
