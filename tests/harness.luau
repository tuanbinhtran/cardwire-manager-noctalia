--!nonstrict
-- Minimal assertion harness shared by the test suites.
local M = {}

local assertions = 0
local failures = 0

local function render(value)
  if type(value) ~= "table" then
    return tostring(value)
  end

  local keys = {}
  for key in pairs(value) do
    table.insert(keys, key)
  end
  table.sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)
  local parts = {}
  for _, key in ipairs(keys) do
    table.insert(parts, `{render(key)}={render(value[key])}`)
  end
  return "{" .. table.concat(parts, ", ") .. "}"
end

local function deepEqual(actual, expected)
  if type(actual) ~= type(expected) then
    return false
  end
  if type(actual) ~= "table" then
    return actual == expected
  end

  for key, value in pairs(actual) do
    if expected[key] == nil or not deepEqual(value, expected[key]) then
      return false
    end
  end
  for key in pairs(expected) do
    if actual[key] == nil then
      return false
    end
  end
  return true
end

function M.eq(name, actual, expected)
  assertions += 1
  if not deepEqual(actual, expected) then
    failures += 1
    print(`FAIL {name}: expected {render(expected)} got {render(actual)}`)
  end
end

-- Prints the summary and raises when any assertion failed (non-zero exit).
function M.finish(suite)
  print(`{suite}: {assertions - failures} passed, {failures} failed`)
  if failures > 0 then
    error("tests failed")
  end
end

return M
