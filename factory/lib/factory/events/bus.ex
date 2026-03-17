defmodule Factory.Events.Bus do
  @moduledoc """
  Event bus backed by Phoenix.PubSub.
  Publishes session lifecycle events for SSE consumers.
  """

  @pubsub Factory.PubSub
  @global_topic "factory:events"

  def subscribe, do: Phoenix.PubSub.subscribe(@pubsub, @global_topic)
  def subscribe(session_name), do: Phoenix.PubSub.subscribe(@pubsub, "session:#{session_name}")

  def publish(event_type, payload \\ %{}) do
    event = %{
      type: event_type,
      payload: payload,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Phoenix.PubSub.broadcast(@pubsub, @global_topic, {:factory_event, event})

    if session_name = payload[:name] || payload[:session] do
      Phoenix.PubSub.broadcast(@pubsub, "session:#{session_name}", {:factory_event, event})
    end

    :ok
  end
end
