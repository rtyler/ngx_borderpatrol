local json = require("json")
local sessionid = require("sessionid")

-------------------------------------------
-- get service token using master token
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

ngx.req.read_body()
local args = ngx.req.get_post_args()
local master_token = args['mastertoken']
local service = args['service']

if master_token and service then
  ngx.log(ngx.DEBUG, "==== master token: " .. master_token )
  local params = {}
  params['services'] = service
  ngx.req.set_header("Auth-Token", master_token)

  res = ngx.location.capture('/mastertoken', { method = ngx.HTTP_POST, body = ngx.encode_args(params)})

  ngx.log(ngx.DEBUG, "==== POST /mastertoken " .. res.status .. " " .. res.body)
  ngx.req.clear_header("Auth-Token")

  -- assume any 2xx is success
  if res.status >= ngx.HTTP_SPECIAL_RESPONSE then
    ngx.log(ngx.DEBUG, "==== error getting service token using master token: ")
    ngx.exit(ngx.HTTP_BAD_REQUEST)
  end
else
  ngx.log(ngx.DEBUG, "==== master token missing: ")
  ngx.exit(ngx.HTTP_BAD_REQUEST)
end
ngx.say(res.body)
ngx.exit(ngx.HTTP_OK)

