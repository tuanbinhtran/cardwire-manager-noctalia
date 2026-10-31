--!nonstrict
-- Shared contract between the service and the UI entries (bar, panel).
local M = {}

M.STATUS_KEY = "cardwire.status"
M.CMD_KEY = "cardwire.cmd"
M.PANEL_ID = "tuanbinhtran/cardwire-manager:panel"

-- Snapshot published by the service on STATUS_KEY. UI entries use it until the
-- service has published (state.watch does not replay the current value).
function M.emptyStatus()
  return {
    modes = {},        -- lowercase mode names in cardwire order
    active = "",       -- lowercase active mode, "" when unknown
    error = "",        -- last error text, "" when none
    updated = "",      -- "HH:MM:SS" of the last successful read
    refreshing = false,
    applying = false,
    loading = true,    -- startup loading (initial read + retries pending)
  }
end

local seq = 0

-- Publish a command for the service: action is "refresh", "set" or "cycle".
-- The id makes every command a distinct value so repeated commands still notify.
function M.send(action, mode)
  seq += 1
  noctalia.state.set(M.CMD_KEY, {
    action = action,
    mode = mode or "",
    id = `{noctalia.nowMs()}-{seq}-{math.random(1, 1000000000)}`,
  })
end

return M
