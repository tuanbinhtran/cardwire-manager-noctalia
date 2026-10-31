--!nonstrict
-- [[service]] entry: wires the Cardwire controller to Noctalia's service globals.
local controller = require("./lib/controller.luau").new({
  noctalia = noctalia,
  cardwire = require("./lib/cardwire.luau"),
  protocol = require("./lib/protocol.luau"),
  date = os.date,
})

function update()
  controller.update()
end

function onIpc(event, payload)
  controller.handle(event, payload)
end

function onConfigChanged()
  controller.onConfigChanged()
end

controller.start()
