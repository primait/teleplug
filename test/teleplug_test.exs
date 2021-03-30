defmodule TeleplugTest do
  use ExUnit.Case
  use Plug.Test

  require OpenTelemetry.Tracer, as: Tracer
  require Record

  doctest Teleplug

  @span_fields Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl")
  Record.defrecord(:span, @span_fields)

  setup do
    :application.stop(:opentelemetry)

    :application.set_env(:opentelemetry, :processors, [
      {:otel_batch_processor, %{scheduled_delay_ms: 1}}
    ])

    :application.start(:opentelemetry)

    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())
    :ok
  end

  test "teleplug sets the span context" do
    assert Tracer.current_span_ctx() == :undefined
    opts = Teleplug.init([])

    _conn =
      :get
      |> conn("/")
      |> Teleplug.call(opts)

    assert Tracer.current_span_ctx() != :undefined
  end

  test "teleplug attributes " do
    opts = Teleplug.init(service_name: :name)

    Tracer.with_span "test" do
      conn =
        :get
        |> conn("/")
        |> Teleplug.call(opts)

      _ =
        conn
        |> Map.get(:before_send)
        |> Enum.reduce(conn, fn h, c0 ->
          h.(c0)
        end)
    end

    receive do
      {:span, span} ->
        assert span(span, :attributes) ==
                 [
                   {"http.status_code", nil},
                   {"service.name", :name},
                   {"http.method", "GET"},
                   {"http.route", "/"},
                   {"http.target", "/"},
                   {"http.host", ""},
                   {"http.scheme", :http},
                   {"http.flavor", ""},
                   {"http.user_agent", ""},
                   {"http.client_ip", "127.0.0.1"},
                   {"net.peer.ip", "127.0.0.1"},
                   {"net.peer.port", 111_317},
                   {"net.host.name", "www.example.com"},
                   {"net.host.port", 80}
                 ]
    after
      100 ->
        raise "Span not found"
    end
  end
end
