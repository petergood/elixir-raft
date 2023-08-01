defmodule RaftNodeTest do
  use ExUnit.Case, async: true
  import Mock

  setup_with_mocks([
    {DateTime, [:passthrough], [utc_now: fn() ->
      {:ok, date, 0} = DateTime.from_iso8601("2023-07-29T23:50:07Z")
      date
    end]}
  ]) do
    :ok
  end

  describe "append_entries" do
    test "returns current term" do
      {:ok, last_heartbeat, 0} = DateTime.from_iso8601("2023-07-29T23:50:07Z")

      state = %RaftNodeState{current_term: 41}
      response = RaftNode.handle_call({:append_entries, %AppendEntriesRequest{}}, nil, state)

      expected_state = %RaftNodeState{state | last_leader_heartbeat: last_heartbeat}
      assert {:reply, %AppendEntriesResponse{term: 41, success: true}, ^expected_state} = response
    end
  end

  describe "check_leader_heartbeat" do
    test "transitions into candidate state when timeout exceeded" do
      with_mock GenServer, [cast: fn(_node, _request) -> :ok end] do
        {:ok, last_heartbeat, 0} = DateTime.from_iso8601("2023-07-28T23:50:07Z")
        state = %RaftNodeState{
          current_term: 41,
          last_leader_heartbeat: last_heartbeat,
          node_config: %RaftNodeConfiguration{leader_timeout_ms: 1000, nodes: ['node1', 'node2'], node_id: 1}
        }

        response = RaftNode.handle_info(:check_leader_heartbeat, state)

        assert {:noreply, %RaftNodeState{state: :candidate, current_term: 42}} = response
        assert_called GenServer.cast({:global, {:VoteOrchestrator, 1}}, {:begin_election, ['node1', 'node2'], 42})
      end
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

  describe "request_vote" do
    test "votes for node when no vote has been cast yet" do
      state = %RaftNodeState{
        voted_for: nil,
        current_term: 41
      }

      response = RaftNode.handle_call({:request_vote, %RequestVoteRequest{term: 42, candidateId: 11}}, nil, state)

      assert {:reply, %RequestVoteResponse{term: 42, voteGranted: true}, %RaftNodeState{current_term: 42, voted_for: 11}} = response
    end

    test "votes for node with larger term" do
      state = %RaftNodeState{
        voted_for: 12,
        current_term: 41
      }

      response = RaftNode.handle_call({:request_vote, %RequestVoteRequest{term: 42, candidateId: 11}}, nil, state)

      assert {:reply, %RequestVoteResponse{term: 42, voteGranted: true}, %RaftNodeState{current_term: 42, voted_for: 11}} = response
    end

    test "rejects second candidate in same term" do
      state = %RaftNodeState{
        voted_for: 12,
        current_term: 42
      }

      response = RaftNode.handle_call({:request_vote, %RequestVoteRequest{term: 42, candidateId: 11}}, nil, state)

      assert {:reply, %RequestVoteResponse{term: 42, voteGranted: false}, %RaftNodeState{current_term: 42, voted_for: 12}} = response
    end

    test "rejects node with stale term" do
      state = %RaftNodeState{
        voted_for: 12,
        current_term: 42
      }

      response = RaftNode.handle_call({:request_vote, %RequestVoteRequest{term: 40, candidateId: 11}}, nil, state)

      assert {:reply, %RequestVoteResponse{term: 42, voteGranted: false}, %RaftNodeState{current_term: 42, voted_for: 12}} = response
    end
  end

  describe "cast election_complete" do
    test "moves into leader state upon winning election" do
      response = RaftNode.handle_cast({:election_complete, true, 42}, %RaftNodeState{node_config: %RaftNodeConfiguration{}})
      assert {:noreply, %RaftNodeState{state: :leader, current_term: 42}} = response
    end

    test "moves into follower state upon loosing election" do
      response = RaftNode.handle_cast({:election_complete, false, 42}, %RaftNodeState{node_config: %RaftNodeConfiguration{}})
      assert {:noreply, %RaftNodeState{state: :follower, current_term: 42}} = response
    end
  end
end
