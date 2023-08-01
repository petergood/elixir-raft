defmodule VoteOrchestratorTest do
  use ExUnit.Case
  import Mock

  @nodes [
    {:global, {:RaftNode, 0}},
    {:global, {:RaftNode, 1}},
    {:global, {:RaftNode, 2}},
    {:global, {:RaftNode, 3}},
    {:global, {:RaftNode, 4}},
  ]

  describe "collect_votes" do
    test "node wins election when majority vote for node" do
      with_mock GenServer, [call: fn(server, _req) ->
        case server do
          {:global, {:RaftNode, 1}} -> %RequestVoteResponse{term: 41, voteGranted: true}
          {:global, {:RaftNode, 2}} -> %RequestVoteResponse{term: 41, voteGranted: true}
          {:global, {:RaftNode, 3}} -> %RequestVoteResponse{term: 41, voteGranted: false}
          {:global, {:RaftNode, 4}} -> %RequestVoteResponse{term: 41, voteGranted: false}
        end
      end] do
        assert {true, 41} = VoteOrchestrator.collect_votes(@nodes, 41, 0)
      end
    end

    test "node looses election when minority vote" do
      with_mock GenServer, [call: fn(server, _req) ->
        case server do
          {:global, {:RaftNode, 1}} -> %RequestVoteResponse{term: 41, voteGranted: true}
          {:global, {:RaftNode, 2}} -> %RequestVoteResponse{term: 41, voteGranted: false}
          {:global, {:RaftNode, 3}} -> %RequestVoteResponse{term: 41, voteGranted: false}
          {:global, {:RaftNode, 4}} -> %RequestVoteResponse{term: 41, voteGranted: false}
        end
      end] do
        assert {false, 41} = VoteOrchestrator.collect_votes(@nodes, 41, 0)
      end
    end

    test "node looses election when majority vote but larger term present" do
      with_mock GenServer, [call: fn(server, _req) ->
        case server do
          {:global, {:RaftNode, 1}} -> %RequestVoteResponse{term: 41, voteGranted: true}
          {:global, {:RaftNode, 2}} -> %RequestVoteResponse{term: 41, voteGranted: true}
          {:global, {:RaftNode, 3}} -> %RequestVoteResponse{term: 41, voteGranted: true}
          {:global, {:RaftNode, 4}} -> %RequestVoteResponse{term: 42, voteGranted: false}
        end
      end] do
        assert {false, 42} = VoteOrchestrator.collect_votes(@nodes, 41, 0)
      end
    end

    test "node looses election when minority vote and larger term present" do
      with_mock GenServer, [call: fn(server, _req) ->
        case server do
          {:global, {:RaftNode, 1}} -> %RequestVoteResponse{term: 41, voteGranted: true}
          {:global, {:RaftNode, 2}} -> %RequestVoteResponse{term: 41, voteGranted: false}
          {:global, {:RaftNode, 3}} -> %RequestVoteResponse{term: 41, voteGranted: false}
          {:global, {:RaftNode, 4}} -> %RequestVoteResponse{term: 42, voteGranted: false}
        end
      end] do
        assert {false, 42} = VoteOrchestrator.collect_votes(@nodes, 41, 0)
      end
    end
  end
end
