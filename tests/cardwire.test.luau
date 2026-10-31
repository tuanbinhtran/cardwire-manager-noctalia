--!nonstrict
local cardwire = require("../cardwire-manager/lib/cardwire")
local harness = require("./harness")
local eq = harness.eq

eq("parseGet standard output", cardwire.parseGet("Current Mode: Smart\nAvailable Mode: integrated, hybrid, smart\n"), {
  current = "smart",
  available = { "integrated", "hybrid", "smart" },
})
eq("parseGet CRLF and plural label", cardwire.parseGet("Current Mode: Hybrid\r\nAvailable Modes: Hybrid, Manual\r\n"), {
  current = "hybrid",
  available = { "hybrid", "manual" },
})
eq("parseGet lowercase and empty list items", cardwire.parseGet("current mode: INTEGRATED\navailable mode: Integrated ,  , Smart"), {
  current = "integrated",
  available = { "integrated", "smart" },
})
eq("parseGet empty", cardwire.parseGet(""), nil)
eq("parseGet nil", cardwire.parseGet(nil), nil)
eq("parseGet missing current value", cardwire.parseGet("Current Mode:\nAvailable Mode: hybrid"), nil)
eq("parseGet unrecognized output", cardwire.parseGet("daemon unavailable"), nil)
eq("parseGet missing available modes", cardwire.parseGet("Current Mode: Smart\n"), nil)
eq("formatModeLabel simple", cardwire.formatModeLabel("smart"), "Smart")
eq("formatModeLabel underscore", cardwire.formatModeLabel("hybrid_mode"), "Hybrid Mode")
eq("formatModeLabel repeated separators", cardwire.formatModeLabel("a-b  c"), "A B C")
eq("formatModeLabel empty", cardwire.formatModeLabel(""), "")
eq("formatModeLabel nil", cardwire.formatModeLabel(nil), "")
eq("nextMode following active", cardwire.nextMode({ "integrated", "hybrid", "smart" }, "hybrid"), "smart")
eq("nextMode wraps", cardwire.nextMode({ "integrated", "hybrid", "smart" }, "smart"), "integrated")
eq("nextMode empty active", cardwire.nextMode({ "integrated", "hybrid", "smart" }, ""), "integrated")
eq("nextMode unknown active", cardwire.nextMode({ "integrated", "hybrid", "smart" }, "unknown"), "integrated")
eq("nextMode empty modes", cardwire.nextMode({}, "x"), nil)
eq("barText formatted mode", cardwire.barText("smart", false, "NM"), "Smart")
eq("barText abbreviated mode", cardwire.barText("smart", true, "NM"), "S")
eq("barText no mode abbreviated", cardwire.barText("", true, "NM"), "NM")
eq("barText no mode", cardwire.barText("", false, "NM"), "NM")
eq("outputText stderr", cardwire.outputText({ stderr = "  error: cardwired daemon is not running. Is the service up?\n", stdout = "" }), "error: cardwired daemon is not running. Is the service up?")
eq("outputText stdout", cardwire.outputText({ stderr = "", stdout = " out \n" }), "out")
eq("outputText empty result", cardwire.outputText({}), "")
eq("outputText nil", cardwire.outputText(nil), "")
eq("trim nil", cardwire.trim(nil), "")
eq("trim whitespace", cardwire.trim("  a b \t"), "a b")

harness.finish("cardwire")
