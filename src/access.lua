local responses = require "kong.tools.responses"
local http = require"socket.http"
local ltn12 = require"ltn12"
local JSON = require "kong.plugins.middleman.json"

local get_headers = ngx.req.get_headers
local get_uri_args = ngx.req.get_uri_args
local read_body = ngx.req.read_body
local get_body = ngx.req.get_body_data

local _M = {}

function _M.execute(conf)    
    local post_url = conf.url  
    local payload = _M.compose_payload()
    
    local response_body = { }
    
    local res, code, response_headers, status = http.request
    {
      url = post_url,
      method = "POST",
      headers = _M.compose_headers(payload:len()),
      source = ltn12.source.string(payload),
      sink = ltn12.sink.table(response_body)
    }
    
    
    if code > 299 then
      return responses.send(code,table.concat(response_body))
    end

end

function _M.compose_headers(len)
    return {
      ["Content-Type"] = "application/json",
      ["Content-Length"] = len
    }
end

function _M.compose_payload()
    local headers = get_headers()
    local uri_args = get_uri_args()
    read_body()
    local body_data = get_body()

    headers["target_uri"] = ngx.var.request_uri
    headers["target_method"] = ngx.var.request_method
    
    local raw_json_headers    = JSON:encode(headers)
    local raw_json_uri_args    = JSON:encode(uri_args)
    local raw_json_body_data    = JSON:encode(body_data)
  
    return [[ {"headers":]] .. raw_json_headers .. [[,"uri_args":]] .. raw_json_uri_args.. [[,"body_data":]] .. raw_json_body_data .. [[} ]]
end

return _M
