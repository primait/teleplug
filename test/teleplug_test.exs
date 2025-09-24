defmodule TeleplugTest do
  use ExUnit.Case, async: true
  import Plug.Test

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
      :get
      |> conn("/")
      |> Teleplug.call(opts)
      |> Plug.Conn.send_resp(200, "ok")
    end

    assert_receive {:span, span(attributes: attributes_record, name: "GET /")}, 1_000
    assert {:attributes, _, _, _, attributes} = attributes_record

    assert %{
             "http.route" => "/",
             "client.address" => "127.0.0.1",
             "http.request.method" => "GET",
             "http.response.status_code" => 200,
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

    assert_receive {:span, span(status: {:status, :error, ""})}, 1_000
  end

  test "teleplug submits span if process is killed before sending response" do
    child =
      spawn(fn ->
        opts = Teleplug.init([])

        conn =
          :get
          |> conn("/")
          |> Teleplug.call(opts)

        Process.sleep(:infinity)
        Plug.Conn.send_resp(conn, 200, "ok")
      end)

    Process.sleep(200)
    Process.exit(child, :kill)

    assert_receive {:span, span(attributes: attributes_record, name: "GET /")}, 1_000
    assert {:attributes, _, _, _, attributes} = attributes_record

    assert %{
             "http.route" => "/",
             "client.address" => "127.0.0.1",
             "http.request.method" => "GET",
             "network.peer.address" => "127.0.0.1",
             "network.peer.port" => 111_317,
             "network.protocol.name" => "",
             "server.address" => "www.example.com",
             "server.port" => 80,
             "url.path" => "/",
             "url.query" => "",
             "url.scheme" => :http
           } = attributes
  end

  test "trace propagation as parent by default" do
    opts = Teleplug.init([])

    {propagated_span_id, propagation_headers} =
      Tracer.with_span "propagated" do
        span_id =
          OpenTelemetry.Tracer.current_span_ctx()
          |> OpenTelemetry.Span.span_id()

        headers = :otel_propagator_text_map.inject([])
        {span_id, headers}
      end

    :get
    |> conn("/")
    |> Plug.Conn.merge_req_headers(propagation_headers)
    |> Teleplug.call(opts)
    |> Plug.Conn.send_resp(200, "ok")

    assert_receive {:span, span(parent_span_id: ^propagated_span_id, name: "GET /")}, 1_000
  end

  test "trace propagation as link" do
    opts = Teleplug.init(trace_propagation: :as_link)

    {propagated_span_id, propagation_headers} =
      Tracer.with_span "propagated" do
        span_id =
          OpenTelemetry.Tracer.current_span_ctx()
          |> OpenTelemetry.Span.span_id()

        headers = :otel_propagator_text_map.inject([])
        {span_id, headers}
      end

    :get
    |> conn("/")
    |> Plug.Conn.merge_req_headers(propagation_headers)
    |> Teleplug.call(opts)
    |> Plug.Conn.send_resp(200, "ok")

    assert_receive {:span, span(links: links, name: "GET /")}, 1_000
    assert {:links, _, _, _, _, [link]} = links
    assert {:link, _, ^propagated_span_id, _, _} = link
    dbg(link)
  end

  test "trace propagation disabled" do
    opts = Teleplug.init(trace_propagation: :disabled)

    propagation_headers =
      Tracer.with_span "propagated" do
        :otel_propagator_text_map.inject([])
      end

    :get
    |> conn("/")
    |> Plug.Conn.merge_req_headers(propagation_headers)
    |> Teleplug.call(opts)
    |> Plug.Conn.send_resp(200, "ok")

    assert_receive {:span, span(parent_span_id: :undefined, links: links, name: "GET /")}, 1_000
    assert {:links, _, _, _, _, []} = links
  end

  def flush_mailbox do
    receive do
      _ -> flush_mailbox()
    after
      10 -> :ok
    end
  end
end
