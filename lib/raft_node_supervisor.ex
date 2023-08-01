defmodule RaftNodeSupervisor do
  use Supervisor

  def start_link(%RaftNodeConfiguration{node_id: node_id} = raft_node_configuration) do
    Supervisor.start_link(__MODULE__, raft_node_configuration, name: {:global, {:RaftNodeSupervisor, node_id}})
  end

  def init(%RaftNodeConfiguration{node_id: node_id} = raft_node_configuration) do
    children = [
      {RaftNode, raft_node_configuration},
      {VoteOrchestrator, node_id}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
