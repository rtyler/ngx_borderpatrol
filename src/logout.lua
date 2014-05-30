-------------------------------------------
-- delete auth token by session id
-------------------------------------------

local args = ngx.req.get_uri_args()
local destination = args['destination']

-- default to reasonable paths.
-- allow only relative paths
if not destination or string.sub(destination,1,1) ~= '/' then destination = '/' end

local session_id = ngx.var.cookie_border_session

if session_id then
  ngx.log(ngx.DEBUG, "==== session_id: " .. session_id)

  -- expires a session
  local res = ngx.location.capture('/session_delete?id=BPSID_' .. session_id,
    { method = ngx.HTTP_DELETE })

  ngx.log(ngx.DEBUG, "DELETE /session_delete?id=BPSID_" .. session_id .. " " .. res.status)

  -- expires the temporary url session
  local res = ngx.location.capture('/session_delete?id=BP_URL_SID_' .. session_id,
    { method = ngx.HTTP_DELETE })

  ngx.log(ngx.DEBUG, "DELETE /session_delete?id=BP_URL_SID_" .. session_id .. " " .. res.status)

  -- unset session cookie (expires now() - 1yr)
  ngx.header['Set-Cookie'] = 'border_session=' ..
    '; path=/; expires=' .. ngx.cookie_time(ngx.time() - 3600 * 24 * 360)

else
    ngx.log(ngx.INFO, "==== session_id not set")
end

ngx.redirect(destination)