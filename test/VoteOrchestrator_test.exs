defmodule VoteOrchestratorTest do
  use ExUnit.Case
  import Mock
  doctest Elixirraft

  @nodes ['node1', 'node2', 'node3', 'node4', 'node5']

  describe "collect_votes" do
    test "node wins election when majority vote for node" do
      with_mock GenServer, [multi_call: fn(_nodes, _name, _request) ->
        {[
          {'node1', %RequestVoteResponse{term: 41, voteGranted: true}},
          {'node2', %RequestVoteResponse{term: 41, voteGranted: true}},
          {'node3', %RequestVoteResponse{term: 41, voteGranted: true}},
          {'node4', %RequestVoteResponse{term: 41, voteGranted: true}},
          {'node5', %RequestVoteResponse{term: 41, voteGranted: false}}
        ], {}}
      end] do
        assert {true, 41} = VoteOrchestrator.collect_votes(@nodes, 41, 11)
      end
    end

    test "node looses election when minority vote" do
      with_mock GenServer, [multi_call: fn(_nodes, _name, _request) ->
        {[
          {'node1', %RequestVoteResponse{term: 41, voteGranted: false}},
          {'node2', %RequestVoteResponse{term: 41, voteGranted: false}},
          {'node3', %RequestVoteResponse{term: 41, voteGranted: false}},
          {'node4', %RequestVoteResponse{term: 41, voteGranted: true}},
          {'node5', %RequestVoteResponse{term: 41, voteGranted: true}}
        ], {}}
      end] do
        assert {false, 41} = VoteOrchestrator.collect_votes(@nodes, 41, 11)
      end
    end

    test "node looses election when majority vote but larger term present" do
      with_mock GenServer, [multi_call: fn(_nodes, _name, _request) ->
        {[
          {'node1', %RequestVoteResponse{term: 41, voteGranted: true}},
          {'node2', %RequestVoteResponse{term: 41, voteGranted: true}},
          {'node3', %RequestVoteResponse{term: 41, voteGranted: true}},
          {'node4', %RequestVoteResponse{term: 41, voteGranted: true}},
          {'node5', %RequestVoteResponse{term: 42, voteGranted: false}}
        ], {}}
      end] do
        assert {false, 42} = VoteOrchestrator.collect_votes(@nodes, 41, 11)
      end
    end

    test "node looses election when minority vote and larger term present" do
      with_mock GenServer, [multi_call: fn(_nodes, _name, _request) ->
        {[
          {'node1', %RequestVoteResponse{term: 41, voteGranted: false}},
          {'node2', %RequestVoteResponse{term: 41, voteGranted: false}},
          {'node3', %RequestVoteResponse{term: 41, voteGranted: true}},
          {'node4', %RequestVoteResponse{term: 41, voteGranted: true}},
          {'node5', %RequestVoteResponse{term: 42, voteGranted: false}}
        ], {}}
      end] do
        assert {false, 42} = VoteOrchestrator.collect_votes(@nodes, 41, 11)
      end
    end
  end
end
