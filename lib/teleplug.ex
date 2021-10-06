defmodule Teleplug do
  @moduledoc """
  Simple opentelementry instrumented plug.
  """

  alias Plug.Conn

  require Logger
  require OpenTelemetry.Tracer, as: Tracer
  require Record

  @span_ctx_fields Record.extract(:span_ctx,
                     from_lib: "opentelemetry_api/include/opentelemetry.hrl"
                   )

  Record.defrecord(:span_ctx, @span_ctx_fields)

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    :otel_propagator.text_map_extract(conn.req_headers)

    attributes =
      http_common_attributes(conn) ++
        http_server_attributes(conn) ++
        network_attributes(conn)

    parent_ctx = Tracer.current_span_ctx()

    route = Teleplug.Instrumentation.get_route(conn.request_path)

    new_ctx = Tracer.start_span(route, %{kind: :server, attributes: attributes})

    Tracer.set_current_span(new_ctx)

    Logger.metadata(
      trace_id: span_ctx(new_ctx, :trace_id),
      span_id: span_ctx(new_ctx, :span_id)
    )

    Conn.register_before_send(conn, fn conn ->
      Tracer.set_attribute("http.status_code", conn.status)
      Tracer.end_span()

      Tracer.set_current_span(parent_ctx)
      conn
    end)
  end

  # see https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/trace/semantic_conventions/http.md#common-attributes
  defp http_common_attributes(
         %Conn{
           adapter: adapter,
           method: method,
           request_path: request_path,
           scheme: scheme
         } = conn
       ),
       do: [
         {"http.method", method},
         {"http.route", request_path},
         {"http.target", http_target(conn)},
         {"http.host", header_value(conn, "host")},
         {"http.scheme", scheme},
         {"http.flavor", http_flavor(adapter)},
         {"http.user_agent", header_value(conn, "user-agent")}
       ]

  # see https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/trace/semantic_conventions/http.md#http-server-semantic-conventions
  defp http_server_attributes(conn),
    do: [{"http.client_ip", client_ip(conn)}]

  # see https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/trace/semantic_conventions/span-general.md#general-network-connection-attributes
  defp network_attributes(
         %Conn{
           host: host,
           port: port
         } = conn
       ) do
    peer_data = Plug.Conn.get_peer_data(conn)

    [
      {"net.peer.ip", peer_data |> Map.get(:address) |> :inet_parse.ntoa() |> to_string()},
      {"net.peer.port", Map.get(peer_data, :port)},
      {"net.host.name", host},
      {"net.host.port", port}
    ]
  end

  defp http_target(%Conn{request_path: request_path, query_string: ""}),
    do: request_path

  defp http_target(%Conn{request_path: request_path, query_string: query_string}),
    do: "#{request_path}?#{query_string}"

  defp header_value(conn, header),
    do:
      conn
      |> Plug.Conn.get_req_header(header)
      |> List.first()
      |> to_string()

  defp http_flavor({_adapter_name, meta}),
    do:
      meta
      |> Map.get(:version)
      |> to_string()
      |> String.trim_leading("HTTP/")

  defp client_ip(%Conn{remote_ip: remote_ip} = conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [] ->
        to_string(:inet_parse.ntoa(remote_ip))

      [client | _] ->
        client
    end
  end
end
