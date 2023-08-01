defmodule RaftNodeConfiguration do
  defstruct node_id: 0, nodes: [], leader_timeout_ms: 1000, leader_heartbeat_check_interval: 800, leader_heartbeat_interval: 500
end

defmodule RaftNodeState do
  defstruct current_term: 0,
    last_leader_heartbeat: 0,
    state: :follower,
    node_config: nil,
    voted_for: nil,
    heartbeat_check_timer_ref: nil,
    heartbeat_timer_ref: nil
end

defmodule RaftNode do
  use GenServer

  def start_link(%RaftNodeConfiguration{node_id: node_id} = raft_node_configuration) do
    GenServer.start_link(__MODULE__, raft_node_configuration, name: {:global, {:RaftNode, node_id}})
  end

  def init(%RaftNodeConfiguration{leader_heartbeat_check_interval: interval} = node_configuration) do
    timer_ref = schedule_leader_heartbeat_check(interval)
    {:ok, %RaftNodeState{node_config: node_configuration, last_leader_heartbeat: DateTime.utc_now(), heartbeat_check_timer_ref: timer_ref}}
  end

  def handle_call({:request_vote, %RequestVoteRequest{term: term, candidateId: candidateId}}, _from, %RaftNodeState{current_term: current_term} = state) do
    cond do
      term > current_term ->
        {:reply, %RequestVoteResponse{term: term, voteGranted: true}, %RaftNodeState{ state | current_term: term, voted_for: candidateId }}
      term <= current_term ->
        {:reply, %RequestVoteResponse{term: current_term, voteGranted: false}, state}
    end
  end

  def handle_call({:append_entries, %AppendEntriesRequest{}}, _from, %RaftNodeState{current_term: current_term} = state) do
    # TODO - stub
    {:reply, %AppendEntriesResponse{term: current_term, success: true}, %RaftNodeState{state | last_leader_heartbeat: DateTime.utc_now()}}
  end

  def handle_cast({:election_complete, true, latest_term}, %RaftNodeState{
    node_config: %RaftNodeConfiguration{leader_heartbeat_interval: interval}
  } = state) do
    timer_ref = schedule_heartbeat(interval)
    {:noreply, %RaftNodeState{state | state: :leader, current_term: latest_term, heartbeat_timer_ref: timer_ref}}
  end
  def handle_cast({:election_complete, false, latest_term}, %RaftNodeState{
    node_config: %RaftNodeConfiguration{leader_heartbeat_check_interval: check_interval}
  } = state) do
    timer_ref = schedule_leader_heartbeat_check(check_interval)
    {:noreply, %RaftNodeState{state | state: :follower, current_term: latest_term, heartbeat_check_timer_ref: timer_ref}}
  end

  def handle_info(:check_leader_heartbeat,
    %RaftNodeState{last_leader_heartbeat: last_heartbeat,
      node_config: %RaftNodeConfiguration{leader_timeout_ms: timeout_ms, leader_heartbeat_check_interval: check_interval}} = state) do
    cond do
      DateTime.diff(DateTime.utc_now(), last_heartbeat, :millisecond) >= timeout_ms ->
        {:noreply, begin_election_state(state)}
      true ->
        timer_ref = schedule_leader_heartbeat_check(check_interval)
        {:noreply, %RaftNodeState{state | heartbeat_check_timer_ref: timer_ref}}
    end
  end

  defp schedule_leader_heartbeat_check(interval) do
    Process.send_after(self(), :check_leader_heartbeat, interval)
  end

  defp schedule_heartbeat(interval) do
    Process.send_after(self(), :send_leader_heartbeat, interval)
  end

  defp begin_election_state(%RaftNodeState{current_term: last_term, node_config: %RaftNodeConfiguration{nodes: nodes, node_id: node_id}} = state) do
    GenServer.cast({:global, {:VoteOrchestrator, node_id}}, {:begin_election, nodes, last_term + 1})
    %RaftNodeState{ state | state: :candidate, current_term: last_term + 1 }
  end
end
