--!nonstrict
-- Drives the service state machine with a fake Noctalia host: a manual clock,
-- runAsync calls captured for the test to complete, and an in-memory state store.
local cardwire = require("../cardwire-manager/lib/cardwire")
local protocol = require("../cardwire-manager/lib/protocol")
local controller = require("../cardwire-manager/lib/controller")
local harness = require("./harness")
local eq = harness.eq

local GET_OK = { exitCode = 0, stdout = "Current Mode: Smart\nAvailable Mode: integrated, hybrid, smart\n", stderr = "", timedOut = false }
local SET_OK = { exitCode = 0, stdout = "", stderr = "", timedOut = false }

local function failed(stderr)
  return { exitCode = 1, stdout = "", stderr = stderr, timedOut = false }
end

-- Translation stub: the key plus sorted params, so assertions see what was formatted.
local function tr(key, params)
  if params == nil then
    return key
  end
  local names = {}
  for name in pairs(params) do
    table.insert(names, name)
  end
  table.sort(names)
  local parts = { key }
  for _, name in ipairs(names) do
    table.insert(parts, `{name}={params[name]}`)
  end
  return table.concat(parts, " ")
end

-- Returns a started fake host. opts: config (getConfig values), launchFails (runAsync returns false).
local function start(opts)
  opts = opts or {}
  local h = { now = 0, calls = {}, values = {}, watchers = {}, notifications = {} }
  local api = {
    tr = tr,
    nowMs = function()
      return h.now
    end,
    getConfig = function(key)
      return (opts.config or {})[key]
    end,
    runAsync = function(argv, callback, timeoutMs)
      if opts.launchFails then
        return false
      end
      table.insert(h.calls, { argv = table.concat(argv, " "), callback = callback, timeoutMs = timeoutMs })
      return true
    end,
    notifyError = function(title, body)
      table.insert(h.notifications, { title = title, body = body })
    end,
    log = function() end,
    setUpdateInterval = function() end,
    state = {
      get = function(key)
        return h.values[key]
      end,
      set = function(key, value)
        h.values[key] = value
        for _, watcher in ipairs(h.watchers[key] or {}) do
          watcher(value)
        end
      end,
      watch = function(key, watcher)
        h.watchers[key] = h.watchers[key] or {}
        table.insert(h.watchers[key], watcher)
      end,
    },
  }
  h.ctl = controller.new({
    noctalia = api,
    cardwire = cardwire,
    protocol = protocol,
    date = function()
      return "12:00:00"
    end,
  })
  h.ctl.start()
  return h
end

local function status(h)
  return h.values[protocol.STATUS_KEY]
end

local function complete(h, index, result)
  h.calls[index].callback(result)
end

local function advance(h, ms)
  h.now += ms
  h.ctl.update()
end

local function lastCommand(h)
  local call = h.calls[#h.calls]
  return call and call.argv
end

do
  local h = start()
  eq("startup reads with a 5 s timeout", { h.calls[1].argv, h.calls[1].timeoutMs }, { "cardwire get", 5000 })
  eq("startup publishes loading while reading", { status(h).loading, status(h).refreshing }, { true, true })
end

do
  local h = start()
  complete(h, 1, GET_OK)
  eq("successful read publishes the mode", status(h), {
    modes = { "integrated", "hybrid", "smart" },
    active = "smart",
    error = "",
    updated = "12:00:00",
    refreshing = false,
    applying = false,
    loading = false,
  })
end

do
  local h = start()
  h.ctl.handle("refresh")
  h.ctl.handle("refresh")
  eq("refreshes during a read do not start another read", #h.calls, 1)
  complete(h, 1, GET_OK)
  eq("refreshes during a read coalesce into one follow-up", { #h.calls, lastCommand(h) }, { 2, "cardwire get" })
end

do
  local h = start()
  complete(h, 1, GET_OK)
  h.ctl.handle("refresh")
  complete(h, 2, { exitCode = 0, stdout = "garbage", stderr = "", timedOut = false })
  eq("unrecognized output keeps the last mode", { status(h).active, status(h).error }, { "smart", "error.unrecognized_output" })
end

do
  local h = start({ launchFails = true })
  eq("launch failure reports that cardwire could not run", status(h).error, "error.launch_failed command=get")
end

do
  local h = start()
  complete(h, 1, GET_OK)
  h.ctl.handle("set", " Hybrid ")
  eq("switch runs cardwire set with a 15 s timeout", { lastCommand(h), h.calls[2].timeoutMs }, { "cardwire set hybrid", 15000 })
  complete(h, 2, SET_OK)
  eq("successful switch shows the new mode immediately", status(h).active, "hybrid")
  advance(h, 399)
  eq("verification read waits 400 ms", #h.calls, 2)
  advance(h, 1)
  eq("verification read runs 400 ms after the switch", { #h.calls, lastCommand(h) }, { 3, "cardwire get" })
end

do
  local h = start()
  complete(h, 1, GET_OK)
  h.ctl.handle("set", "hybrid")
  complete(h, 2, failed("error: boom"))
  eq("failed switch keeps the mode and shows stderr", { status(h).active, status(h).error }, { "smart", "error: boom" })
  eq("failed switch raises an error notification", h.notifications, { { title = "notify.switch_failed", body = "error: boom" } })
end

do
  local h = start()
  complete(h, 1, GET_OK)
  h.ctl.handle("set", "smart")
  eq("switch to the active mode is ignored", #h.calls, 1)
  h.ctl.handle("refresh")
  h.ctl.handle("set", "hybrid")
  eq("switch while reading is ignored", lastCommand(h), "cardwire get")
end

do
  local h = start()
  complete(h, 1, GET_OK)
  h.ctl.handle("cycle")
  eq("cycle switches to the next mode, wrapping", lastCommand(h), "cardwire set integrated")
end

do
  local h = start()
  complete(h, 1, GET_OK)
  advance(h, 14999)
  eq("poll waits for the interval", #h.calls, 1)
  advance(h, 1)
  eq("poll reads after the default 15 s", { #h.calls, lastCommand(h) }, { 2, "cardwire get" })
end

do
  local h = start({ config = { polling_enabled = false } })
  complete(h, 1, GET_OK)
  advance(h, 600000)
  eq("disabled polling never reads", #h.calls, 1)
end

do
  local h = start()
  complete(h, 1, failed("down"))
  eq("startup failure keeps loading", status(h).loading, true)
  advance(h, 2000)
  complete(h, 2, failed("down"))
  advance(h, 5000)
  complete(h, 3, failed("down"))
  advance(h, 9999)
  eq("startup retries run after 2 s and 5 s", #h.calls, 3)
  advance(h, 1)
  eq("third startup retry runs after 10 s", #h.calls, 4)
  complete(h, 4, failed("down"))
  eq("exhausted startup retries show the error", { status(h).loading, status(h).error }, { false, "down" })
end

-- Regression: a poll that came due during a failed switch was dropped and never re-armed.
do
  local h = start()
  complete(h, 1, GET_OK)
  h.ctl.handle("set", "hybrid")
  advance(h, 15000)
  complete(h, 2, failed("error: timed out"))
  advance(h, 15000)
  eq("polling resumes after a failed switch that spanned a poll", { #h.calls, lastCommand(h) }, { 3, "cardwire get" })
end

-- Regression: a startup retry swallowed by a failed switch left loading stuck forever.
do
  local h = start()
  complete(h, 1, failed("down"))
  h.ctl.handle("set", "hybrid")
  advance(h, 2000)
  complete(h, 2, failed("error: boom"))
  advance(h, 10000)
  eq("startup retry is re-armed after a failed switch", { #h.calls, lastCommand(h) }, { 3, "cardwire get" })
end

-- Regression: a failed manual refresh during startup consumed a retry (DMS counts timer firings only).
do
  local h = start()
  complete(h, 1, failed("down"))
  advance(h, 500)
  h.ctl.handle("refresh")
  complete(h, 2, failed("down"))
  advance(h, 2000)
  eq("manual refresh during startup keeps the 2 s retry", { #h.calls, lastCommand(h) }, { 3, "cardwire get" })
end

do
  local h = start()
  complete(h, 1, failed("down"))
  h.ctl.handle("set", "")
  eq("empty mode while no mode is known is ignored", h.notifications, {})
end

do
  local h = start()
  h.ctl.handle("set", "  ")
  eq("empty mode while reading is ignored", h.notifications, {})
end

do
  local h = start()
  complete(h, 1, GET_OK)
  h.ctl.handle("set", "")
  eq("empty mode with a known mode reports an error", { status(h).error, h.notifications }, {
    "error.mode_empty",
    { { title = "notify.switch_failed", body = "error.mode_empty" } },
  })
end

do
  local h = start()
  complete(h, 1, GET_OK)
  advance(h, 10000)
  h.ctl.handle("refresh")
  complete(h, 2, GET_OK)
  advance(h, 5000)
  eq("manual refresh does not delay the next poll", { #h.calls, lastCommand(h) }, { 3, "cardwire get" })
end

do
  local cfg = {}
  local h = start({ config = cfg })
  complete(h, 1, GET_OK)
  advance(h, 10000)
  h.ctl.onConfigChanged()
  advance(h, 5000)
  eq("unchanged settings keep the poll schedule", #h.calls, 2)
end

do
  local cfg = {}
  local h = start({ config = cfg })
  complete(h, 1, GET_OK)
  advance(h, 10000)
  cfg.poll_interval_seconds = 30
  h.ctl.onConfigChanged()
  advance(h, 29999)
  eq("interval change restarts the poll deadline", #h.calls, 1)
  advance(h, 1)
  eq("restarted poll fires at the new interval", #h.calls, 2)
end

harness.finish("controller")
