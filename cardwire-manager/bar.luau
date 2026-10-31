--!nonstrict
local cardwire = require("./lib/cardwire.luau")
local protocol = require("./lib/protocol.luau")
local tr = noctalia.tr

local status = noctalia.state.get(protocol.STATUS_KEY) or protocol.emptyStatus()
local abbreviate = noctalia.getConfig("abbreviate_mode_names") == true

local function render()
  local showError = (not status.loading) and status.error ~= ""
  barWidget.setGlyph(showError and "alert-triangle" or "cpu")
  barWidget.setGlyphColor(showError and "error" or "on_surface")
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

function update()
  render()
end

function onClick()
  noctalia.togglePanel(protocol.PANEL_ID)
end

function onRightClick()
  protocol.send("cycle")
end

render()
