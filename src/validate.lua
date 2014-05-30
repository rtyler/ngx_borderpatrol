local json = require("json")
local sessionid = require("sessionid")

-------------------------------------------
-- Lookup auth token by session id
-------------------------------------------

local session_id = ngx.var.cookie_border_session

if not session_id then
  ngx.log(ngx.INFO, "==== access denied: no session_id")
  ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

ngx.log(ngx.DEBUG, "==== session_id: " .. session_id)

if not sessionid.is_valid(session_id) then
  ngx.log(ngx.INFO, "==== access denied: session id invalid " .. session_id)
  ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

local auth_token = nil
local all_tokens_json = nil

local res = ngx.location.capture('/session?id=BPSID_' .. session_id)
ngx.log(ngx.DEBUG, "GET /session?id=BPSID_" .. session_id .. " " ..
  res.status)

local all_tokens = nil

if res.status == ngx.HTTP_OK then
  all_tokens_json = res.body
  all_tokens = json.decode(all_tokens_json, {nothrow = true})

  if all_tokens then
    -- get service name from uri
    local service_uri = string.match(ngx.var.request_uri,"^/([^/]+)")
    local service = nil
    if service_uri then
      service = service_mappings[service_uri]
    end

    auth_token = all_tokens['service_tokens'][service]

    if not auth_token then
      ngx.log(ngx.INFO, "==== token not found in session for service : " .. service_uri)
      master_token = all_tokens['auth_service']
      if master_token then
        local params = {}
        params['mastertoken'] = master_token
        params['service'] = service
        res = ngx.location.capture('/serviceauth', { method = ngx.HTTP_POST, body = ngx.encode_args(params) })

        -- TODO Check response status (in this case, don't do anything, treat it as missing token)
        local specific_token_json = res.body
        auth_token = json.decode(specific_token_json, {nothrow = true})['service_tokens'][service]
        if auth_token then
          all_tokens['service_tokens'][service] = auth_token
          all_tokens_json = json.encode(all_tokens)
        end
        ngx.log(ngx.INFO, "==== retrieved service token for service: " .. service .. " " .. auth_token)
      end
    end
    -- reset the auth_token TTL to maintain a rolling session window
    res = ngx.location.capture('/session?id=BPSID_' .. session_id ..
      "&exptime=" .. sessionid.EXPTIME, { body = all_tokens_json, method = ngx.HTTP_PUT })
    if res.status ~= ngx.HTTP_CREATED then
      ngx.log(ngx.WARN, "==== failed to refresh session w/ id " .. session_id ..
        " " .. res.status)
    end
  end
end

if not auth_token then
  ngx.log(ngx.INFO, "==== access denied: no auth token for session_id " ..
    session_id)
  ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

-- If we made it this far, we're good. Inject the Auth-Token header
ngx.header['Auth-Token'] = auth_token
ngx.log(ngx.INFO, "==== request auth header set")
ngx.exit(ngx.HTTP_OK)
