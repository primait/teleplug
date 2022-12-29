defmodule TeleplugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  require OpenTelemetry.Tracer, as: Tracer
  require Record

  doctest Teleplug

  @span_fields Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl")
  Record.defrecord(:span, @span_fields)

  setup do
    flush_mailbox()
    :otel_simple_processor.set_exporter(:otel_exporter_pid, self())
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
    opts = Teleplug.init([])

    Tracer.with_span "test" do
      conn =
        :get
        |> conn("/")
        |> Teleplug.call(opts)

      _ =
        conn
        |> Map.get(:private)
        |> Map.get(:before_send)
        |> Enum.reduce(conn, fn h, c0 ->
          h.(c0)
        end)
    end

    assert_receive {:span, span(attributes: attributes_record)}, 1_000
    assert {:attributes, _, _, _, attributes} = attributes_record

    assert %{
             "http.status_code" => nil,
             "http.method" => "GET",
             "http.route" => "/",
             "http.target" => "/",
             "http.host" => "",
             "http.scheme" => :http,
             "http.client_ip" => "127.0.0.1",
             "net.host.port" => 80
           } = attributes
  end

  def flush_mailbox do
    receive do
      _ -> flush_mailbox()
    after
      10 -> :ok
    end
  end
end
