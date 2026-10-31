--!nonstrict
local cardwire = require("./lib/cardwire.luau")
local protocol = require("./lib/protocol.luau")
local tr = noctalia.tr

local GET_TIMEOUT_MS = 5000
local SET_TIMEOUT_MS = 15000
local STARTUP_RETRY_DELAYS_MS = { 2000, 5000, 10000 }
local POST_APPLY_VERIFY_MS = 400
local TICK_MS = 250

local status = protocol.emptyStatus()
local refreshPending = false
local retryIndex = 0
local retryAt = nil
local verifyAt = nil
local nextPollAt = nil
local pollingEnabled = true
local pollIntervalMs = 15000

local function readConfig()
  pollingEnabled = noctalia.getConfig("polling_enabled") ~= false
  local secs = math.clamp(math.floor(tonumber(noctalia.getConfig("poll_interval_seconds")) or 15), 5, 120)
  pollIntervalMs = secs * 1000
end

local function publish()
  noctalia.state.set(protocol.STATUS_KEY, table.clone(status))
end

local function busy()
  return status.refreshing or status.applying
end

local function schedulePoll()
  nextPollAt = (pollingEnabled and not status.loading) and (noctalia.nowMs() + pollIntervalMs) or nil
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
  local ok = noctalia.runAsync({ "cardwire", "get" }, onGetResult, GET_TIMEOUT_MS)
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
      status.updated = os.date("%H:%M:%S")
    end
  end

  if status.loading then
    if status.error == "" or retryIndex >= #STARTUP_RETRY_DELAYS_MS then
      status.loading = false
    else
      retryIndex += 1
      retryAt = noctalia.nowMs() + STARTUP_RETRY_DELAYS_MS[retryIndex]
    end
  end

  schedulePoll()
  publish()
  if refreshPending then
    refresh()
  end
end

function setMode(mode)
  mode = string.lower(cardwire.trim(mode))
  if mode == "" then
    status.error = tr("error.mode_empty")
    publish()
    noctalia.notifyError(tr("notify.switch_failed"), status.error)
    return
  end
  if busy() or mode == status.active then
    return
  end

  verifyAt = nil
  status.applying = true
  publish()
  local ok = noctalia.runAsync({ "cardwire", "set", mode }, function(result)
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
    publish()
    noctalia.notifyError(tr("notify.switch_failed"), status.error)
    return
  end

  status.active = mode
  status.error = ""
  refreshPending = false
  verifyAt = noctalia.nowMs() + POST_APPLY_VERIFY_MS
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
    noctalia.log("cardwire-manager: unknown command " .. tostring(action))
  end
end

function update()
  local now = noctalia.nowMs()
  if retryAt ~= nil and retryAt <= now then
    retryAt = nil
    refresh()
  end
  if verifyAt ~= nil and verifyAt <= now then
    verifyAt = nil
    refresh()
  end
  if nextPollAt ~= nil and nextPollAt <= now then
    nextPollAt = nil
    refresh()
  end
end

function onIpc(event, payload)
  handle(event, payload)
end

function onConfigChanged()
  readConfig()
  schedulePoll()
end

noctalia.state.watch(protocol.CMD_KEY, function(cmd)
  if type(cmd) == "table" then
    handle(cmd.action, cmd.mode)
  end
end)

readConfig()
noctalia.setUpdateInterval(TICK_MS)
publish()
refresh()
