defmodule VoteOrchestratorState do
  defstruct node_id: 0,
    raft_node_pid: nil
end

defmodule VoteOrchestrator do
  use GenServer

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def init({node_id, raft_node_pid}) do
    {:ok, %VoteOrchestratorState{node_id: node_id, raft_node_pid: raft_node_pid}}
  end

  def handle_cast({:begin_election, nodes, term}, %VoteOrchestratorState{node_id: node_id, raft_node_pid: raft_node_pid}) do
    {was_elected, latest_term} = collect_votes(nodes, term, node_id)
    GenServer.cast(raft_node_pid, {:election_complete, was_elected, latest_term})
  end

  def collect_votes(nodes, term, node_id) do
    {replies, _bad_nodes} = GenServer.multi_call(nodes, :RaftNode, %RequestVoteRequest{term: term, candidateId: node_id})

    # TODO - error handling (bad_nodes)

    received_votes = replies |>
      Enum.map(fn {_node, response} -> response end) |>
      Enum.filter(fn %RequestVoteResponse{voteGranted: vote_granted, term: voterTerm} -> vote_granted == true and term == voterTerm end) |>
      Enum.count

    latest_term = replies |>
      Enum.map(fn {_node, %RequestVoteResponse{term: term}} -> term end) |>
      Enum.max

    node_count = Enum.count(nodes)
    {received_votes > :math.floor(node_count / 2) and latest_term <= term, latest_term}
  end
end
