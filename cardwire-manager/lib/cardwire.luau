--!nonstrict
local M = {}

function M.trim(s)
  if s == nil then
    return ""
  end
  return string.match(s, "^%s*(.-)%s*$") or ""
end

function M.parseGet(stdout)
  if stdout == nil then
    return nil
  end

  local current = ""
  local available = {}
  local foundCurrent = false
  local foundAvailable = false

  for line in string.gmatch(stdout .. "\n", "(.-)\n") do
    line = string.gsub(line, "\r$", "")
    line = string.lower(line)

    local currentCapture = string.match(line, "^current mode:[ \t]*(.+)$")
    if not foundCurrent and currentCapture ~= nil then
      current = M.trim(currentCapture)
      foundCurrent = true
    end

    local availableCapture = string.match(line, "^available modes?:[ \t]*(.+)$")
    if not foundAvailable and availableCapture ~= nil then
      foundAvailable = true
      for mode in string.gmatch(availableCapture .. ",", "(.-),") do
        mode = M.trim(mode)
        if mode ~= "" then
          table.insert(available, mode)
        end
      end
    end
  end

  if current == "" or #available == 0 then
    return nil
  end

  return { current = current, available = available }
end

function M.formatModeLabel(name)
  if name == nil or name == "" then
    return ""
  end

  local parts = {}
  for part in string.gmatch(name, "[^-_%s]+") do
    table.insert(parts, string.upper(string.sub(part, 1, 1)) .. string.sub(part, 2))
  end
  return table.concat(parts, " ")
end

function M.nextMode(modes, active)
  if #modes == 0 then
    return nil
  end

  local index = 0
  for i, mode in ipairs(modes) do
    if mode == active then
      index = i
      break
    end
  end
  return modes[(index % #modes) + 1]
end

function M.barText(active, abbreviate, noModeText)
  if active == "" then
    return noModeText
  end
  if abbreviate then
    return string.upper(string.sub(active, 1, 1))
  end
  return M.formatModeLabel(active)
end

function M.outputText(result)
  if result == nil then
    return ""
  end
  local stderr = M.trim(result.stderr)
  if stderr ~= "" then
    return stderr
  end
  return M.trim(result.stdout)
end

return M
