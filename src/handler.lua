local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.middleman.access"

local MiddlemanHandler = BasePlugin:extend()

MiddlemanHandler.PRIORITY = 900

function MiddlemanHandler:new()
  MiddlemanHandler.super.new(self, "middleman")
end

function MiddlemanHandler:access(conf)
  MiddlemanHandler.super.access(self)
  access.execute(conf)
end

return MiddlemanHandler