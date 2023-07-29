defmodule RaftNodeTest do
  use ExUnit.Case, async: true
  import Mock
  doctest Elixirraft

  describe "append_entries" do
    test "returns current term" do
      state = %RaftNodeState{current_term: 41}
      response = RaftNode.handle_call({:append_entries, %AppendEntriesRequest{}}, nil, state)

      assert {:reply, %AppendEntriesResponse{term: 41, success: true}, state} = response
    end
  end

  describe "check_leader_heartbeat" do
    setup_with_mocks([
      {DateTime, [:passthrough], [utc_now: fn() ->
        {:ok, date, 0} = DateTime.from_iso8601("2023-07-29T23:50:07Z")
        date
      end]}
    ]) do
      :ok
    end

    test "transitions into candidate when timeout exceeded" do
      {:ok, last_heartbeat, 0} = DateTime.from_iso8601("2023-07-28T23:50:07Z")
      state = %RaftNodeState{
        last_leader_heartbeat: last_heartbeat,
        node_config: %RaftNodeConfiguration{leader_timeout_ms: 1000}
      }

      response = RaftNode.handle_info(:check_leader_heartbeat, state)

      assert {:noreply, %RaftNodeState{state: :candidate}} = response
    end

    test "schedules next heartbeat when timeout not exceeded" do
      {:ok, last_heartbeat, 0} = DateTime.from_iso8601("2023-07-29T23:50:06Z")
      state = %RaftNodeState{
        last_leader_heartbeat: last_heartbeat,
        node_config: %RaftNodeConfiguration{leader_timeout_ms: 2000, leader_heartbeat_check_interval: 800}
      }

      response = RaftNode.handle_info(:check_leader_heartbeat, state)

      assert {:noreply, %RaftNodeState{state: :follower}} = response
    end
  end
end
