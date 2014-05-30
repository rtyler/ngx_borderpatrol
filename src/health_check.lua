--
-- This script serves up an HTML page that displays current health of the
-- BorderPatrol. The only check, currently, is that memcache is reachable.
--
local errors = {}
local health_check = {}

-- print out the actual HTML
function health_check.output(errors)
  ngx.header.content_type = 'text/html';
  ngx.print([[
  <html>
    <head>
      <title>Border Patrol Health</title>
    </head>
    <body>
  ]])

  if #errors > 0 then
    ngx.print("<h3>Errors</h3><ul>")
    for i, v in ipairs(errors) do
      ngx.print("<li>" .. v .. "</li>")
    end
    ngx.print("</ul>")
  else
    ngx.print("Everything is ok.")
  end

  ngx.print([[
    </body>
  </html>
  ]])
end

local res = ngx.location.capture('/session?id=health_check', { method = ngx.HTTP_POST, body = os.time() })
if not res.status == ngx.HTTP_OK then
  errors[#errors+1] = "memcache add: " .. res.status .. ": " .. res.body
end

res = ngx.location.capture('/session?id=health_check')
if not res.status == ngx.HTTP_OK then
  errors[#errors+1] = "memcache get: " .. res.status .. ": " .. res.body
end

res = ngx.location.capture('/session?id=health_check', { method = ngx.HTTP_PUT, body = os.time() })
if not res.status == ngx.HTTP_OK then
  errors[#errors+1] = "memcache set: " .. res.status .. ": " .. res.body
end

res = ngx.location.capture('/session?id=health_check', { method = ngx.HTTP_DELETE })
if not res.status == ngx.HTTP_OK then
  errors[#errors+1] = "memcache delete: " .. res.status .. ": " .. res.body
end

health_check.output(errors)
