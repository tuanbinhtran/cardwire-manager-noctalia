--!nonstrict
local cardwire = require("./lib/cardwire.luau")
local protocol = require("./lib/protocol.luau")
local tr = noctalia.tr

local status = noctalia.state.get(protocol.STATUS_KEY) or protocol.emptyStatus()
local abbreviate = noctalia.getConfig("abbreviate_mode_names") == true
local rendered = false
-- Unique per runtime; a rare same-ms collision only merges two leases until the next heartbeat.
local widgetId = `{noctalia.nowMs()}-{math.random(1, 1000000000)}`
local lastAnnounceMs = noctalia.nowMs()
protocol.announce(widgetId, true)

local function render()
  local showError = (not status.loading) and status.error ~= ""
  barWidget.setGlyph(showError and "alert-triangle" or "cpu")
  barWidget.setGlyphColor(showError and "error" or "on_surface")
  -- "on_surface" from setColor/setGlyphColor means the host's configured default.
  barWidget.setColor(showError and "error" or "on_surface")
  barWidget.setText(cardwire.barText(status.active, abbreviate, tr("bar.no_mode")))

  local modeText = status.active ~= "" and cardwire.formatModeLabel(status.active) or tr("status.no_mode")
  local statusText = status.loading and tr("status.loading")
    or (status.error ~= "" and status.error)
    or (status.updated ~= "" and tr("status.updated", { time = status.updated }))
    or tr("status.no_mode")
  barWidget.setTooltip({ { tr("bar.tooltip_mode"), modeText }, { tr("bar.tooltip_status"), statusText } })
end

noctalia.state.watch(protocol.STATUS_KEY, function(v)
  if type(v) == "table" then
    status = v
    render()
  end
end)

-- The first host tick renders; afterwards the status watch drives every render.
function update()
  if not rendered then
    rendered = true
    render()
  end
  local now = noctalia.nowMs()
  if now - lastAnnounceMs >= protocol.WIDGET_HEARTBEAT_MS then
    lastAnnounceMs = now
    protocol.announce(widgetId, true)
  end
end

function onExit()
  protocol.announce(widgetId, false)
end

function onClick()
  noctalia.togglePanel(protocol.PANEL_ID)
end

function onRightClick()
  protocol.send("cycle")
end
