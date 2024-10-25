local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("json")
local meta = require("_meta")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")

local function checkForUpdates()
  local response_body = {}
  local _, code = http.request {
    url = "https://api.github.com/repos/drewbaumann/AskGPT/releases/latest",
    headers = {
        ["Accept"] = "application/vnd.github.v3+json"
    },
    sink = ltn12.sink.table(response_body)
  }

  if code == 200 then
    local data = table.concat(response_body)
    local parsed_data = json.decode(data)
    local latest_version = parsed_data.tag_name -- e.g., "v0.9"
    local stripped_latest_version = latest_version:match("^v(.+)$")
    -- Compare with current version
    if meta.version < tonumber(stripped_latest_version) then
      -- Show notification to the user if a new version is available
      local message = "A new version of the app (" .. latest_version .. ") is available. Please update!"
      local info_message = InfoMessage:new{
          text = message,
          timeout = 5 -- Display message for 5 seconds
      }
      UIManager:show(info_message)
    end
  else
    print("Failed to check for updates. HTTP code:", code)
  end
end

return {
  checkForUpdates = checkForUpdates
}