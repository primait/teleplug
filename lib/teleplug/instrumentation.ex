defmodule Teleplug.Instrumentation do
  @moduledoc """
  Instrumentation module. Setup telemetry handlers to add information to traces.
  """

  @key {:teleplug, :route}

  @plug_router_prefix [:plug, :router_dispatch]
  @phoenix_router_prefix [:phoenix, :router_dispatch]

  @start_events [@plug_router_prefix ++ [:start], @phoenix_router_prefix ++ [:start]]
  @end_events [
    @plug_router_prefix ++ [:stop],
    @plug_router_prefix ++ [:exception],
    @phoenix_router_prefix ++ [:stop],
    @phoenix_router_prefix ++ [:exception]
  ]

  def setup do
    OpenTelemetry.register_application_tracer(:teleplug)
    
    # attach to plug and phoenix route dispatch events so it works when using one or the other
    Enum.each(@start_events, fn event -> attach_to_event(event, &__MODULE__.register_route/4) end)
    Enum.each(@end_events, fn event -> attach_to_event(event, &__MODULE__.unregister_route/4) end)
  end

  defp attach_to_event(event, function),
    do: :telemetry.attach(inspect(event), event, function, nil)

  def register_route(_event, _measurements, %{route: route}, _config),
    do: Process.put(@key, route)

  def unregister_route(_event, _measurements, _, _config), do: Process.delete(@key)

  def get_route(default), do: Process.get(@key, default)
end
