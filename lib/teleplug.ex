defmodule Teleplug do
  @moduledoc """
  Simple opentelementry instrumented plug.
  """

  alias Plug.Conn

  alias OpenTelemetry.SemConv.ClientAttributes
  alias OpenTelemetry.SemConv.HTTPAttributes
  alias OpenTelemetry.SemConv.NetworkAttributes
  alias OpenTelemetry.SemConv.ServerAttributes
  alias OpenTelemetry.SemConv.URLAttributes
  alias OpenTelemetry.SemConv.UserAgentAttributes

  alias Teleplug.RequestMonitor

  require Logger

  require OpenTelemetry.Tracer, as: Tracer
  require Record

  @client_address Atom.to_string(ClientAttributes.client_address())

  @http_request_method Atom.to_string(HTTPAttributes.http_request_method())
  @http_response_status_code Atom.to_string(HTTPAttributes.http_response_status_code())
  @http_route Atom.to_string(HTTPAttributes.http_route())

  @url_path Atom.to_string(URLAttributes.url_path())
  @url_query Atom.to_string(URLAttributes.url_query())
  @url_scheme Atom.to_string(URLAttributes.url_scheme())

  @user_agent_original Atom.to_string(UserAgentAttributes.user_agent_original())

  @server_address Atom.to_string(ServerAttributes.server_address())
  @server_port Atom.to_string(ServerAttributes.server_port())

  @network_peer_address Atom.to_string(NetworkAttributes.network_peer_address())
  @network_peer_port Atom.to_string(NetworkAttributes.network_peer_port())
  @network_protocol_name Atom.to_string(NetworkAttributes.network_protocol_name())

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

    new_ctx = conn |> span_name() |> Tracer.start_span(%{kind: :server, attributes: attributes})

    Tracer.set_current_span(new_ctx)

    request_monitor_ref = RequestMonitor.start(new_ctx)

    Conn.register_before_send(conn, fn conn ->
      # https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/trace/semantic_conventions/http.md#status
      if conn.status >= 500 do
        Tracer.set_status(:error, "")
      end

      Tracer.set_attribute(@http_response_status_code, conn.status)
      RequestMonitor.end_span(request_monitor_ref)

      Tracer.set_current_span(parent_ctx)
      conn
    end)
  end

  # see https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/semantic_conventions/http.md#name
  defp span_name(conn),
    do: "#{conn.method} #{Teleplug.Instrumentation.get_route(conn.request_path)}"

  # see https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/trace/semantic_conventions/http.md#common-attributes
  defp http_common_attributes(
         %Conn{
           method: method,
           scheme: scheme
         } = conn
       ) do
    route = Teleplug.Instrumentation.get_route(conn.request_path)

    [
      {@http_request_method, method},
      {@http_route, route},
      {@url_path, url_path(conn)},
      {@url_scheme, scheme},
      {@url_query, url_query(conn)},
      {@user_agent_original, header_value(conn, "user-agent")}
    ]
  end

  # see https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/trace/semantic_conventions/http.md#http-server-semantic-conventions
  defp http_server_attributes(conn),
    do: [{@client_address, client_ip(conn)}]

  # see https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/trace/semantic_conventions/span-general.md#general-network-connection-attributes
  defp network_attributes(
         %Conn{
           adapter: adapter,
           host: host,
           port: port
         } = conn
       ) do
    peer_data = Plug.Conn.get_peer_data(conn)

    [
      {@network_peer_address,
       peer_data |> Map.get(:address) |> :inet_parse.ntoa() |> to_string()},
      {@network_peer_port, Map.get(peer_data, :port)},
      {@network_protocol_name, network_protocol_name(adapter)},
      {@server_address, host},
      {@server_port, port}
    ]
  end

  defp url_path(%Conn{request_path: request_path}),
    do: request_path

  defp url_query(%Conn{query_string: query_string}),
    do: query_string

  defp header_value(conn, header),
    do:
      conn
      |> Plug.Conn.get_req_header(header)
      |> List.first()
      |> to_string()

  defp network_protocol_name({_adapter_name, meta}),
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
