--!nonstrict
-- Cardwire state machine (port of the DMS CardwireService): reads the mode with
-- `cardwire get`, switches with `cardwire set <mode>`, polls, retries at startup,
-- coalesces refreshes and verifies after a switch. All dependencies are injected
-- so tests can drive it with a fake host (Noctalia's require needs the ".luau"
-- suffix, which the standalone luau CLI rejects, so this module requires nothing).
local M = {}

local GET_TIMEOUT_MS = 5000
local SET_TIMEOUT_MS = 15000
local STARTUP_RETRY_DELAYS_MS = { 2000, 5000, 10000 }
local POST_APPLY_VERIFY_MS = 400
local TICK_MS = 250

-- deps: noctalia (host API), cardwire (lib/cardwire), protocol (lib/protocol),
-- date (os.date-compatible formatter).
function M.new(deps)
  local host = deps.noctalia
  local cardwire = deps.cardwire
  local protocol = deps.protocol
  local date = deps.date
  local tr = host.tr

  local status = protocol.emptyStatus()
  local refreshPending = false
  local retryIndex = 0
  local retryAt = nil
  local verifyAt = nil
  local nextPollAt = nil
  local pollingEnabled = true
  local pollIntervalMs = 15000

  local function readConfig()
    pollingEnabled = host.getConfig("polling_enabled") ~= false
    local secs = math.clamp(math.floor(tonumber(host.getConfig("poll_interval_seconds")) or 15), 5, 120)
    pollIntervalMs = secs * 1000
  end

  local function publish()
    host.state.set(protocol.STATUS_KEY, table.clone(status))
  end

  local function busy()
    return status.refreshing or status.applying
  end

  -- Fixed-rate poll like the DMS repeating Timer: armed when polling becomes
  -- active, restarted only when asked (interval change), cleared when inactive.
  local function syncPoll(restart)
    if not (pollingEnabled and not status.loading) then
      nextPollAt = nil
    elseif restart or nextPollAt == nil then
      nextPollAt = host.nowMs() + pollIntervalMs
    end
  end

  -- retryIndex counts fired retry timers only (as DMS does), so failed manual
  -- refreshes during startup reschedule the current delay without using one up.
  local function scheduleRetry()
    retryAt = host.nowMs() + STARTUP_RETRY_DELAYS_MS[math.min(retryIndex + 1, #STARTUP_RETRY_DELAYS_MS)]
  end

  local function failureText(command, result)
    if result == nil then
      return tr("error.launch_failed", { command = command })
    end
    if result.timedOut then
      return tr("error.timed_out", { command = command })
    end
    local output = cardwire.outputText(result)
    if output ~= "" then
      return output
    end
    return tr("error.exited", { command = command, code = tostring(result.exitCode) })
  end

  local refresh, onGetResult, setMode, onSetResult

  function refresh()
    if busy() then
      refreshPending = true
      return
    end

    retryAt = nil
    refreshPending = false
    status.refreshing = true
    publish()
    local ok = host.runAsync({ "cardwire", "get" }, onGetResult, GET_TIMEOUT_MS)
    if not ok then
      onGetResult(nil)
    end
  end

  function onGetResult(result)
    status.refreshing = false
    if result == nil or result.timedOut or result.exitCode ~= 0 then
      status.error = failureText("get", result)
    else
      local parsed = cardwire.parseGet(result.stdout)
      if parsed == nil then
        status.error = tr("error.unrecognized_output")
      else
        status.modes = parsed.available
        status.active = parsed.current
        status.error = ""
        status.updated = date("%H:%M:%S")
      end
    end

    if status.loading then
      if status.error == "" or retryIndex >= #STARTUP_RETRY_DELAYS_MS then
        status.loading = false
      else
        scheduleRetry()
      end
    end

    syncPoll(false)
    publish()
    if refreshPending then
      refresh()
    end
  end

  function setMode(mode)
    mode = string.lower(cardwire.trim(mode))
    if busy() or mode == status.active then
      return
    end
    if mode == "" then
      status.error = tr("error.mode_empty")
      publish()
      host.notifyError(tr("notify.switch_failed"), status.error)
      return
    end

    verifyAt = nil
    status.applying = true
    publish()
    -- argv form only: the mode is never interpreted by a shell.
    local ok = host.runAsync({ "cardwire", "set", mode }, function(result)
      onSetResult(mode, result)
    end, SET_TIMEOUT_MS)
    if not ok then
      onSetResult(mode, nil)
    end
  end

  function onSetResult(mode, result)
    status.applying = false
    if result == nil or result.timedOut or result.exitCode ~= 0 then
      refreshPending = false
      status.error = failureText("set " .. mode, result)
      -- A startup retry that came due during the switch was dropped with refreshPending; re-arm it.
      if status.loading and retryAt == nil then
        scheduleRetry()
      end
      publish()
      host.notifyError(tr("notify.switch_failed"), status.error)
      return
    end

    status.active = mode
    status.error = ""
    refreshPending = false
    verifyAt = host.nowMs() + POST_APPLY_VERIFY_MS
    publish()
  end

  local function cycle()
    local mode = cardwire.nextMode(status.modes, status.active)
    if mode then
      setMode(mode)
    end
  end

  local function handle(action, mode)
    if action == "refresh" then
      refresh()
    elseif action == "set" then
      setMode(mode)
    elseif action == "cycle" then
      cycle()
    else
      host.log("cardwire-manager: unknown command " .. tostring(action))
    end
  end

  -- Fires due deadlines; a refresh while busy only marks one pending follow-up.
  local function update()
    local now = host.nowMs()
    if retryAt ~= nil and retryAt <= now then
      retryAt = nil
      retryIndex += 1
      refresh()
    end
    if verifyAt ~= nil and verifyAt <= now then
      verifyAt = nil
      refresh()
    end
    if nextPollAt ~= nil and nextPollAt <= now then
      nextPollAt += pollIntervalMs
      if nextPollAt <= now then
        nextPollAt = now + pollIntervalMs -- skip missed ticks (e.g. after suspend)
      end
      refresh()
    end
  end

  local function onConfigChanged()
    local previousIntervalMs = pollIntervalMs
    readConfig()
    syncPoll(pollIntervalMs ~= previousIntervalMs)
  end
  local function start()
    host.state.watch(protocol.CMD_KEY, function(cmd)
      if type(cmd) == "table" then
        handle(cmd.action, cmd.mode)
      end
    end)
    readConfig()
    host.setUpdateInterval(TICK_MS)
    publish()
    refresh()
  end

  return {
    start = start,
    update = update,
    handle = handle,
    onConfigChanged = onConfigChanged,
  }
end

return M
