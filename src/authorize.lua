local json = require("json")
local sessionid = require("sessionid")

-------------------------------------------
--  Make the call to the Account Service
-------------------------------------------

local session_id = ngx.var.cookie_border_session

-- require session because the only valid scenario for arriving here is via redirect, which should have already set
-- session
if not session_id then
  ngx.log(ngx.INFO, "==== access denied: no session_id")
  ngx.exit(ngx.HTTP_UNAUTHORIZED)
end
ngx.log(ngx.DEBUG, "==== session_id: " .. session_id)

if not sessionid.is_valid(session_id) then
  ngx.log(ngx.INFO, "==== access denied: session id invalid " .. session_id)
  ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

-- Retrieve original target url and derive service
local res = ngx.location.capture('/session?id=BP_URL_SID_' .. session_id)

ngx.log(ngx.DEBUG, "==== GET /session?id=BP_URL_SID_" .. session_id .. " " .. res.status)

-- Get original downstream url they were going to before being redirected
original_url = res.body

-- get service name from first part of original uri
local service_uri = string.match(original_url, "^/([^/]+)")
local service = nil
if service_uri then
  ngx.log(ngx.DEBUG, "==== service uri is: " .. service_uri)
  service = service_mappings[service_uri]
end

-- check service
if not service then
  if not service_uri then
    ngx.log(ngx.DEBUG, "==== no valid service uri provided")
  else
    ngx.log(ngx.DEBUG, "==== service not set for service uri: " .. service_uri)
  end
  ngx.redirect('/account/password')
end

ngx.req.read_body()
local args = ngx.req.get_post_args()

-- the account service expects 'e=user@example.com&p=password&t=3&s=servicename'
args['service'] = service
res = ngx.location.capture('/account', { method = ngx.HTTP_POST, body = ngx.encode_args(args) })

ngx.log(ngx.DEBUG, "==== POST /account " .. res.status .. " " .. res.body)

-- assume any 2xx is success
-- On failure, redirect to login
if res.status >= ngx.HTTP_SPECIAL_RESPONSE then
  ngx.log(ngx.DEBUG, "==== Authorization against Account Service failed: " .. res.body)
  ngx.redirect('/account')
end

-- parse the response body
local all_tokens_json = res.body
local all_tokens = json.decode(all_tokens_json)

-- looking for auth tokens
if not all_tokens then
  ngx.log(ngx.DEBUG, "==== no tokens found, redirecting to /account")
  ngx.redirect('/account')
end

-- looking for service token
if not all_tokens["service_tokens"][service] then
  ngx.log(ngx.DEBUG, "==== parse failure, or service token not found, redirecting to /account")
  ngx.redirect('/account')
end

-- Extract token for specific service
local auth_token = all_tokens["service_tokens"][service]

-- store all tokens in memcache via internal subrequest
local res = ngx.location.capture('/session?id=BPSID_' .. session_id ..
  '&arg_exptime=' .. sessionid.EXPTIME, { body = all_tokens_json, method = ngx.HTTP_PUT })

ngx.log(ngx.DEBUG, "==== PUT /session?id=BPSID_" .. session_id  ..
  '&arg_exptime=' .. sessionid.EXPTIME .. " " .. res.status)

ngx.redirect(original_url)
