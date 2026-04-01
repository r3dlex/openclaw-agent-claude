defmodule Factory.Events.BusTest do
  use ExUnit.Case, async: false

  describe "subscribe/0 and publish/2" do
    test "global subscriber receives published events" do
      Factory.Events.Bus.subscribe()
      Factory.Events.Bus.publish(:test_event, %{data: "hello"})
      assert_receive {:factory_event, event}, 500
      assert event.type == :test_event
      assert event.payload.data == "hello"
      assert is_binary(event.timestamp)
    end

    test "returns :ok from publish/2" do
      assert :ok = Factory.Events.Bus.publish(:any_event, %{})
    end
  end

  describe "subscribe/1 (session-scoped)" do
    test "session subscriber receives events with matching session name in payload" do
      session_name = "bus_test_session_#{:erlang.unique_integer([:positive])}"
      Factory.Events.Bus.subscribe(session_name)
      Factory.Events.Bus.publish(:session_output, %{name: session_name, line: "hello"})
      assert_receive {:factory_event, event}, 500
      assert event.type == :session_output
      assert event.payload.name == session_name
    end

    test "session subscriber does not receive events for other sessions" do
      Factory.Events.Bus.subscribe("my_exclusive_session")
      Factory.Events.Bus.publish(:session_output, %{name: "other_session", line: "hi"})
      refute_receive {:factory_event, _}, 100
    end
  end

  describe "publish/1 (no explicit payload)" do
    test "publishes with empty payload map" do
      Factory.Events.Bus.subscribe()
      Factory.Events.Bus.publish(:no_payload_event)
      assert_receive {:factory_event, event}, 500
      assert event.type == :no_payload_event
      assert event.payload == %{}
    end
  end

  describe "session key routing" do
    test "publishes to session topic when payload has :session key" do
      session_name = "bus_test_session_key_#{:erlang.unique_integer([:positive])}"
      Factory.Events.Bus.subscribe(session_name)
      Factory.Events.Bus.publish(:session_something, %{session: session_name})
      assert_receive {:factory_event, _event}, 500
    end
  end
end
