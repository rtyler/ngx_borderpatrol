local sessionid = require("sessionid")

local original_url = ngx.var.original_uri

-- Create session key and store the url as value (value will be updated later with master and service tokens
local session_id = sessionid.generate();

-- store original url in memcache via internal subrequest
local res = ngx.location.capture('/session?id=BP_URL_SID_' .. session_id ..
  '&arg_exptime=' .. sessionid.EXPTIME_TMP, { body = original_url, method = ngx.HTTP_POST })

ngx.log(ngx.DEBUG, "==== POST /session?id=BP_URL_SID_" .. session_id  ..
  '&arg_exptime=' .. sessionid.EXPTIME .. " " .. res.status)

if res.status == ngx.HTTP_CREATED then
  -- set the cookie with the session_id
  ngx.header['Set-Cookie'] = 'border_session=' .. session_id .. '; path=/; HttpOnly; Secure;'
  -- Redirect to account service login
  ngx.redirect('/account')
else
  ngx.log(ngx.ERR, "==== an error occurred trying to save session: " .. res.status)
  ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end


