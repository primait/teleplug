# Teleplug

[![Module Version](https://img.shields.io/hexpm/v/teleplug.svg)](https://hex.pm/packages/teleplug)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/teleplug/)
[![Total Download](https://img.shields.io/hexpm/dt/teleplug.svg)](https://hex.pm/packages/teleplug)
[![License](https://img.shields.io/hexpm/l/teleplug.svg)](https://github.com/primait/teleplug/blob/master/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/primait/teleplug.svg)](https://github.com/primait/teleplug/commits/master)

Teleplug is a dead simple opentelemetry-instrumented plug.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `teleplug` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:teleplug, "~> 1.0.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/teleplug](https://hexdocs.pm/teleplug).

## Use

In your pipeline add

```
plug Teleplug
```

There are some options you can pass, for example

```
plug Teleplug,
  trace_propagation: :as_link
```

see the module documentation for details

## Copyright and License

Copyright (c) 2020 Prima.it

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the [LICENSE.md](./LICENSE.md) file for more details.
