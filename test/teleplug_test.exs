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

    assert_receive {:span, span(attributes: attributes_record, name: "GET /")}, 1_000
    assert {:attributes, _, _, _, attributes} = attributes_record

    assert %{
             "http.route" => "/",
             "client.address" => "127.0.0.1",
             "http.request.method" => "GET",
             "http.response.status_code" => nil,
             "network.peer.address" => "127.0.0.1",
             "network.peer.port" => 111_317,
             "network.protocol.name" => "",
             "server.address" => "www.example.com",
             "server.port" => 80,
             "url.path" => "/",
             "url.query" => "",
             "url.scheme" => :http,
             "user_agent.original" => ""
           } = attributes
  end

  test "teleplug sets error status on 5xx" do
    opts = Teleplug.init([])

    :get
    |> conn("/")
    |> Teleplug.call(opts)
    |> Plug.Conn.send_resp(500, "Internal server error")
    |> Map.get(:private)
    |> Map.get(:before_send)
    |> Enum.reduce(fn h, c0 ->
      h.(c0)
    end)

    assert_receive {:span, span(status: {:status, :error, ""})}, 1_000
  end

  def flush_mailbox do
    receive do
      _ -> flush_mailbox()
    after
      10 -> :ok
    end
  end
end
