defmodule Teleplug do
  @moduledoc """
  Simple opentelementry instrumented plug.
  """

  alias Plug.Conn

  require Logger
  require OpenTelemetry.SemanticConventions.Trace, as: Conventions
  require OpenTelemetry.Tracer, as: Tracer
  require Record

  @http_client_ip Atom.to_string(Conventions.http_client_ip())
  @http_flavor Atom.to_string(Conventions.http_flavor())
  @http_method Atom.to_string(Conventions.http_method())
  @http_route Atom.to_string(Conventions.http_route())
  @http_scheme Atom.to_string(Conventions.http_scheme())
  @http_status_code Atom.to_string(Conventions.http_status_code())
  @http_target Atom.to_string(Conventions.http_target())
  @http_user_agent Atom.to_string(Conventions.http_user_agent())

  @net_host_name Atom.to_string(Conventions.net_host_name())
  @net_host_port Atom.to_string(Conventions.net_host_port())
  @net_sock_peer_port Atom.to_string(Conventions.net_sock_peer_port())
  @net_sock_peer_addr Atom.to_string(Conventions.net_sock_peer_addr())

  @behaviour Plug

  defdelegate setup, to: Teleplug.Instrumentation

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    :otel_propagator_text_map.extract(conn.req_headers)

    attributes =
      http_common_attributes(conn) ++
        http_server_attributes(conn) ++
        network_attributes(conn)

    parent_ctx = Tracer.current_span_ctx()

    route = Teleplug.Instrumentation.get_route(conn.request_path)

    new_ctx = Tracer.start_span(route, %{kind: :server, attributes: attributes})

    Tracer.set_current_span(new_ctx)

    Conn.register_before_send(conn, fn conn ->
      Tracer.set_attribute(@http_status_code, conn.status)
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
           scheme: scheme
         } = conn
       ) do
    route = Teleplug.Instrumentation.get_route(conn.request_path)

    [
      {@http_method, method},
      {@http_route, route},
      {@http_target, http_target(conn)},
      {@http_scheme, scheme},
      {@http_flavor, http_flavor(adapter)},
      {@http_user_agent, header_value(conn, "user-agent")}
    ]
  end

  # see https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/trace/semantic_conventions/http.md#http-server-semantic-conventions
  defp http_server_attributes(conn),
    do: [{@http_client_ip, client_ip(conn)}]

  # see https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/trace/semantic_conventions/span-general.md#general-network-connection-attributes
  defp network_attributes(
         %Conn{
           host: host,
           port: port
         } = conn
       ) do
    peer_data = Plug.Conn.get_peer_data(conn)

    [
      {@net_sock_peer_addr, peer_data |> Map.get(:address) |> :inet_parse.ntoa() |> to_string()},
      {@net_sock_peer_port, Map.get(peer_data, :port)},
      {@net_host_name, host},
      {@net_host_port, port}
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
