--!nonstrict
local cardwire = require("./lib/cardwire.luau")
local protocol = require("./lib/protocol.luau")
local tr = noctalia.tr

local status = noctalia.state.get(protocol.STATUS_KEY) or protocol.emptyStatus()
local isOpen = false
local hovered = nil
local showClose = true

local function render()
  if not isOpen then
    return
  end

  local showError = (not status.loading) and status.error ~= ""
  local busy = status.refreshing or status.applying
  local activeLabel = status.active ~= "" and cardwire.formatModeLabel(status.active) or tr("status.no_mode")

  local headerChildren = {
    ui.glyph({ name = showError and "alert-triangle" or "cpu", size = 28, color = showError and "error" or "primary" }),
  }
  local titleChildren = {
    ui.label({ text = activeLabel, fontSize = 16, fontWeight = "bold", color = showError and "error" or "on_surface" }),
  }
  if status.loading then
    table.insert(titleChildren, ui.label({ text = tr("status.loading"), color = "on_surface_variant" }))
  elseif showError then
    table.insert(titleChildren, ui.label({ text = status.error, color = "error", maxLines = 2 }))
  end
  table.insert(headerChildren, ui.column({ flexGrow = 1, gap = 2, align = "start" }, titleChildren))
  if showClose then
    table.insert(headerChildren, ui.button({
      glyph = "x",
      variant = "ghost",
      tooltip = tr("panel.close"),
      onClick = function()
        panel.close()
      end,
    }))
  end
  local header = ui.row({ align = "center", gap = 12 }, headerChildren)

  local rows = {}
  for _, name in ipairs(status.modes) do
    local active = name == status.active
    local label = cardwire.formatModeLabel(name)
    table.insert(rows, ui.row({
      key = name, align = "center", gap = 12, padding = 12, radius = 12,
      fill = active and "primary/0.16" or (hovered == name and "on_surface/0.10" or "on_surface/0.05"),
      border = active and "primary" or nil, borderWidth = active and 1 or 0,
      opacity = busy and 0.6 or 1,
      onClick = (not busy and not active) and function() protocol.send("set", name) end or nil,
      onHover = function(state)
        if state == "true" then hovered = name elseif hovered == name then hovered = nil end
        render()
      end,
    }, {
      ui.glyph({ name = active and "circle-check" or "adjustments", size = 20, color = active and "primary" or "on_surface_variant" }),
      ui.column({ flexGrow = 1, gap = 2, align = "start" }, {
        ui.label({ text = label, fontWeight = active and "bold" or "medium", color = "on_surface" }),
        ui.label({ text = tr("panel.mode_description", { mode = label }), fontSize = 12, color = "on_surface_variant" }),
      }),
    }))
  end
  if #status.modes == 0 and not status.loading then
    rows = { ui.label({ text = tr("panel.no_modes"), color = "on_surface_variant" }) }
  end
  local list = ui.scroll({ flexGrow = 1, gap = 8 }, rows)

  local footer = ui.row({ align = "center", gap = 12 }, {
    ui.button({
      text = status.refreshing and tr("panel.refreshing") or tr("panel.refresh"),
      glyph = "refresh",
      enabled = not status.refreshing,
      onClick = function()
        protocol.send("refresh")
      end,
    }),
    ui.label({ text = status.updated ~= "" and tr("status.updated", { time = status.updated }) or "", color = "on_surface_variant", flexGrow = 1 }),
  })

  panel.render(ui.column({ flexGrow = 1, gap = 16 }, { header, list, footer }))
end

noctalia.state.watch(protocol.STATUS_KEY, function(v)
  if type(v) == "table" then
    status = v
    render()
  end
end)

function onOpen(_context)
  isOpen = true
  showClose = noctalia.getSetting("shell.show_close_buttons") ~= false
  status = noctalia.state.get(protocol.STATUS_KEY) or status
  render()
  protocol.send("refresh")
end

function onClose()
  isOpen = false
  hovered = nil
end
