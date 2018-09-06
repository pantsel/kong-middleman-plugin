local responses = require "kong.tools.responses"
local JSON = require "kong.plugins.middleman.json"
local cjson = require "cjson"
local url = require "socket.url"

local string_format = string.format

local get_headers = ngx.req.get_headers
local get_uri_args = ngx.req.get_uri_args
local read_body = ngx.req.read_body
local get_body = ngx.req.get_body_data
local get_method = ngx.req.get_method
local ngx_re_match = ngx.re.match
local ngx_re_find = ngx.re.find

local HTTP = "http"
local HTTPS = "https"

local _M = {}

local function parse_url(host_url)
  local parsed_url = url.parse(host_url)
  if not parsed_url.port then
    if parsed_url.scheme == HTTP then
      parsed_url.port = 80
     elseif parsed_url.scheme == HTTPS then
      parsed_url.port = 443
     end
  end
  if not parsed_url.path then
    parsed_url.path = "/"
  end
  return parsed_url
end

function _M.execute(conf)
  if not conf.run_on_preflight and get_method() == "OPTIONS" then
    return
  end

  local name = "[middleman] "
  local ok, err
  local parsed_url = parse_url(conf.url)
  local host = parsed_url.host
  local port = tonumber(parsed_url.port)
  local payload = _M.compose_payload(parsed_url)

  local sock = ngx.socket.tcp()
  sock:settimeout(conf.timeout)

  ok, err = sock:connect(host, port)
  if not ok then
    ngx.log(ngx.ERR, name .. "failed to connect to " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end

  if parsed_url.scheme == HTTPS then
    local _, err = sock:sslhandshake(true, host, false)
    if err then
      ngx.log(ngx.ERR, name .. "failed to do SSL handshake with " .. host .. ":" .. tostring(port) .. ": ", err)
    end
  end

  ok, err = sock:send(payload)
  if not ok then
    ngx.log(ngx.ERR, name .. "failed to send data to " .. host .. ":" .. tostring(port) .. ": ", err)
  end

  local line, err = sock:receive("*l")

  if err then 
    ngx.log(ngx.ERR, name .. "failed to read response status from " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end

  local status_code = tonumber(string.match(line, "%s(%d%d%d)%s"))
  local headers = {}

  repeat
    line, err = sock:receive("*l")
    if err then
      ngx.log(ngx.ERR, name .. "failed to read header " .. host .. ":" .. tostring(port) .. ": ", err)
      return
    end

    local pair = ngx_re_match(line, "(.*):\\s*(.*)", "jo")

    if pair then
      headers[string.lower(pair[1])] = pair[2]
    end
  until ngx_re_find(line, "^\\s*$", "jo")

  local body, err = sock:receive(tonumber(headers['content-length']))
  if err then
    ngx.log(ngx.ERR, name .. "failed to read body " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end

  ok, err = sock:setkeepalive(conf.keepalive)
  if not ok then
    ngx.log(ngx.ERR, name .. "failed to keepalive to " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end

  if status_code > 299 then
    if err then 
      ngx.log(ngx.ERR, name .. "failed to read response from " .. host .. ":" .. tostring(port) .. ": ", err)
    end

    local response_body
    if conf.response == "table" then 
      response_body = JSON:decode(string.match(body, "%b{}"))
    else
      response_body = string.match(body, "%b{}")
    end

    return responses.send(status_code, response_body)
  end

end

function _M.compose_payload(parsed_url)
    local headers = get_headers()
    local uri_args = get_uri_args()
    local next = next
    
    read_body()
    local body_data = get_body()

    headers["target_uri"] = ngx.var.request_uri
    headers["target_method"] = ngx.var.request_method

    local url
    if parsed_url.query then
      url = parsed_url.path .. "?" .. parsed_url.query
    else
      url = parsed_url.path
    end
    
    local raw_json_headers = JSON:encode(headers)
    local raw_json_body_data = JSON:encode(body_data)

    local raw_json_uri_args
    if next(uri_args) then 
      raw_json_uri_args = JSON:encode(uri_args) 
    else
      -- Empty Lua table gets encoded into an empty array whereas a non-empty one is encoded to JSON object.
      -- Set an empty object for the consistency.
      raw_json_uri_args = "{}"
    end

    local payload_body = [[{"headers":]] .. raw_json_headers .. [[,"uri_args":]] .. raw_json_uri_args.. [[,"body_data":]] .. raw_json_body_data .. [[}]]
    
    local payload_headers = string_format(
      "POST %s HTTP/1.1\r\nHost: %s\r\nConnection: Keep-Alive\r\nContent-Type: application/json\r\nContent-Length: %s\r\n",
      url, parsed_url.host, #payload_body)
  
    return string_format("%s\r\n%s", payload_headers, payload_body)
end

return _M
