defmodule AppendEntriesRequest do
  defstruct term: nil, leaderId: nil, prevLogIndex: nil, prevLogTerm: nil, entries: nil, leaderCommit: nil
end
