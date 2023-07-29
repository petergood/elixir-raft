defmodule RaftNodeConfiguration do
  defstruct leader_timeout_ms: 1000, leader_heartbeat_check_interval: 800
end

defmodule RaftNodeState do
  defstruct current_term: 0, last_leader_heartbeat: 0, state: :follower, node_config: nil
end

defmodule RaftNode do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %RaftNodeConfiguration{}, name: __MODULE__)
  end

  def init(%RaftNodeConfiguration{} = node_configuration) do
    {:ok, %RaftNodeState{node_config: node_configuration}}
  end

  def handle_call({:append_entries, %AppendEntriesRequest{}}, _from, %RaftNodeState{current_term: current_term} = state) do
    {:reply, %AppendEntriesResponse{term: current_term, success: true}, state}
  end

  def handle_info(:check_leader_heartbeat,
    %RaftNodeState{last_leader_heartbeat: last_heartbeat,
      node_config: %RaftNodeConfiguration{leader_timeout_ms: timeout_ms, leader_heartbeat_check_interval: check_interval}} = state) do
    cond do
      DateTime.diff(DateTime.utc_now(), last_heartbeat, :millisecond) >= timeout_ms ->
        {:noreply, %RaftNodeState{ state | state: :candidate }}
      true ->
        schedule_leader_heartbeat_check(check_interval)
        {:noreply, state}
    end
  end

  defp schedule_leader_heartbeat_check(interval) do
    Process.send_after(self(), :check_leader_heartbeat, interval)
  end
end
