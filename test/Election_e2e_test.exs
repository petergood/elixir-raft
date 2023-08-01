defmodule ElectionE2ETest do
  use ExUnit.Case

  @nodes [
    {:global, {:RaftNode, 0}},
    {:global, {:RaftNode, 1}},
    {:global, {:RaftNode, 2}},
    {:global, {:RaftNode, 3}},
    {:global, {:RaftNode, 4}}
  ]

  @node_configs [
    %RaftNodeConfiguration{node_id: 0, leader_heartbeat_check_interval: 500, leader_timeout_ms: 10},
    %RaftNodeConfiguration{node_id: 1},
    %RaftNodeConfiguration{node_id: 2},
    %RaftNodeConfiguration{node_id: 3},
    %RaftNodeConfiguration{node_id: 4}
  ]

  test "election with single candidate" do
    @node_configs |>
      Enum.map(fn %RaftNodeConfiguration{node_id: node_id} = node_config ->
        Supervisor.child_spec({RaftNodeSupervisor, %RaftNodeConfiguration{node_config | nodes: @nodes}}, id: node_id) end) |>
      Enum.each(fn child -> start_supervised(child) end)

    response = GenServer.call({:global, {:RaftNode, 0}}, {:append_entries, %AppendEntriesRequest{}})
    assert %AppendEntriesResponse{term: 0, success: true} = response
  end
end
