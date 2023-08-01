defmodule VoteOrchestratorState do
  defstruct node_id: 0
end

defmodule VoteOrchestrator do
  use GenServer

  def start_link(node_id) do
    GenServer.start_link(__MODULE__, node_id, name: {:global, {:VoteOrchestrator, node_id}})
  end

  def init(node_id) do
    {:ok, %VoteOrchestratorState{node_id: node_id}}
  end

  def handle_cast({:begin_election, nodes, term}, %VoteOrchestratorState{node_id: node_id} = state) do
    {was_elected, latest_term} = collect_votes(nodes, term, node_id)
    IO.inspect "Election for #{node_id}, result: #{was_elected}, term: #{latest_term}"
    GenServer.cast({:global, {:RaftNode, node_id}}, {:election_complete, was_elected, latest_term})

    {:noreply, state}
  end

  def collect_votes(nodes, term, node_id) do
    # TODO - error handling (bad_nodes)
    # TODO - do these requests concurrently

    replies = nodes |>
      Enum.filter(fn {:global, {:RaftNode, id}} -> id != node_id end) |>
      Enum.map(fn node -> GenServer.call(node, {:request_vote, %RequestVoteRequest{term: term, candidateId: node_id}}) end)

    received_votes = replies |>
      Enum.filter(fn %RequestVoteResponse{voteGranted: vote_granted, term: voterTerm} -> vote_granted == true and term == voterTerm end) |>
      Enum.count

    latest_term = replies |>
      Enum.map(fn %RequestVoteResponse{term: term} -> term end) |>
      Enum.max

    node_count = Enum.count(nodes)
    {received_votes + 1 > :math.floor(node_count / 2) and latest_term <= term, latest_term}
  end
end
