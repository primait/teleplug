defmodule Teleplug.RequestMonitor do
  @moduledoc false
  use GenServer
  require Logger

  @type state :: {pid(), OpenTelemetry.span_ctx()}

  @spec start(OpenTelemetry.span_ctx()) :: pid() | nil
  def start(span_ctx) do
    case GenServer.start(__MODULE__, {self(), span_ctx}) do
      {:ok, pid} ->
        pid

      # If some telemetry metadata doesn't get submitted, it's not a big issue
      {:error, err} ->
        Logger.warning(
          "Teleplug failed to start RequestHandlerMonitor. Please report this. #{err}"
        )

        nil

      :ignore ->
        Logger.warning(
          "Teleplug failed to start RequestHandlerMonitor. Please report this. GenServer returned :ignore"
        )

        nil
    end
  end

  def end_span(ref) when is_pid(ref) do
    GenServer.cast(ref, :end_span)
  end

  @impl true
  @spec init(state()) :: {:ok, state()}
  def init({handler_ref, _span_ctx} = state) when is_pid(handler_ref) do
    Process.monitor(handler_ref)
    {:ok, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _, _}, state) do
    handle_end_span(state)
  end

  @impl true
  def handle_cast(:end_span, state) do
    handle_end_span(state)
  end

  defp handle_end_span({_, span_ctx} = state) do
    OpenTelemetry.Span.end_span(span_ctx)
    {:stop, :normal, state}
  end
end
