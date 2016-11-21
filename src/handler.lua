local responses = require "kong.tools.responses"
local BasePlugin = require "kong.plugins.base_plugin"
local http = require"socket.http"
local ltn12 = require"ltn12"
local JSON = require "kong.plugins.middleman.json"

local get_headers = ngx.req.get_headers
local get_uri_args = ngx.req.get_uri_args
local get_body = ngx.req.get_body_data

local MiddlemanHandler = BasePlugin:extend()

MiddlemanHandler.PRIORITY = 2000

function MiddlemanHandler:new()
  MiddlemanHandler.super.new(self, "middleman")
end

function MiddlemanHandler:access(conf)
  MiddlemanHandler.super.access(self)
  
  local post_url = conf.url
  local headers = get_headers()
  local uri_args = get_uri_args()
  local body_data = get_body()
  
  local raw_json_headers    = JSON:encode(headers)
  local raw_json_uri_args    = JSON:encode(uri_args)
  local raw_json_body_data    = JSON:encode(body_data)
  
  local path = post_url
  local payload = [[ {"headers":]] .. raw_json_headers .. [[,"uri_args":]] .. raw_json_uri_args.. [[,"body_data":]] .. raw_json_body_data .. [[} ]]
  
  local response_body = { }
  
  local res, code, response_headers, status = http.request
  {
    url = post_url,
    method = "POST",
    headers =
    {
      ["Content-Type"] = "application/json",
      ["Content-Length"] = payload:len()
    },
    source = ltn12.source.string(payload),
    sink = ltn12.sink.table(response_body)
  }
  
  
  if code > 299 then
	return responses.send(code,table.concat(response_body))
  end
  
end

return MiddlemanHandler