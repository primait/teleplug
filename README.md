# Teleplug
[![Module Version](https://img.shields.io/hexpm/v/prima_opentelemetry_ex.svg)](https://hex.pm/packages/prima_opentelemetry_ex)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/telepoison/)
[![Total Download](https://img.shields.io/hexpm/dt/telepoison.svg)](https://hex.pm/packages/telepoison)
[![License](https://img.shields.io/hexpm/l/telepoison.svg)](https://github.com/primait/telepoison/blob/master/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/primait/telepoison.svg)](https://github.com/primait/telepoison/commits/master)

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

In your pipeline add 

```
plug TelePlug
```

## Copyright and License

Copyright (c) 2020 Prima.it

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the [LICENSE.md](./LICENSE.md) file for more details.

