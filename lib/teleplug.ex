defmodule Teleplug do
  @moduledoc """
  Simple opentelementry instrumented plug.
  """

  alias Plug.Conn

  require Logger
  require OpenTelemetry.Tracer, as: Tracer
  require Record

  @behaviour Plug

  defdelegate setup, to: Teleplug.Instrumentation

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    :otel_propagator_text_map.extract(conn.req_headers)

    attributes =
      http_common_attributes(conn) ++
        http_server_attributes(conn) ++
        network_attributes(conn) ++ service_name(opts)

    parent_ctx = Tracer.current_span_ctx()

    route = Teleplug.Instrumentation.get_route(conn.request_path)

    new_ctx = Tracer.start_span(route, %{kind: :server, attributes: attributes})

    Tracer.set_current_span(new_ctx)

    set_logger_metadata(new_ctx, opts)

    Conn.register_before_send(conn, fn conn ->
      Tracer.set_attribute("http.status_code", conn.status)
      Tracer.end_span()

      Tracer.set_current_span(parent_ctx)
      set_logger_metadata(parent_ctx, opts)
      conn
    end)
  end

  # see https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/trace/semantic_conventions/http.md#common-attributes
  defp http_common_attributes(
         %Conn{
           adapter: adapter,
           method: method,
           scheme: scheme
         } = conn
       ) do
    route = Teleplug.Instrumentation.get_route(conn.request_path)

    [
      {"http.method", method},
      {"http.route", route},
      {"http.target", http_target(conn)},
      {"http.host", header_value(conn, "host")},
      {"http.scheme", scheme},
      {"http.flavor", http_flavor(adapter)},
      {"http.user_agent", header_value(conn, "user-agent")}
    ]
  end

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

  defp service_name(opts) do
    case Keyword.get(opts, :service_name) do
      nil -> []
      service_name -> [{"service.name", service_name}]
    end
  end

  defp set_logger_metadata(:undefined, _opts),
    do: Logger.metadata(trace_id: nil, span_id: nil, dd: nil, service: nil)

  defp set_logger_metadata(span_ctx, opts) do
    trace_id = :otel_span.trace_id(span_ctx)
    span_id = :otel_span.span_id(span_ctx)

    metadata = [
      trace_id: trace_id,
      span_id: span_id,
      dd: [
        trace_id: datadog_trace_id(trace_id),
        span_id: datadog_span_id(span_id)
      ],
      service: Keyword.get(opts, :service_name)
    ]

    Logger.metadata(metadata)
  end

  # converts trace_id to a datadog understandable format (taking the 2nd half of the 128 bits string)
  defp datadog_trace_id(trace_id) do
    <<_::64, datadog_trace_id::64>> = <<trace_id::128>>
    to_string(datadog_trace_id)
  end

  defp datadog_span_id(span_id), do: to_string(span_id)
end
