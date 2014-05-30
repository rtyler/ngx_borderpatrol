if (ngx.var.auth_token == "") then
  -- make a sub request to pull session data
  local res = ngx.location.capture("/auth")

  ngx.log(ngx.DEBUG, "==== GET /auth " .. res.status .. " " .. res.body)

  if res.status == ngx.HTTP_OK then
    -- set the auth token in the request variables so it can be pulled out
    -- and passed as a header then return and allow the request chain to
    -- continue. if there's no auth token do the same thing, allowing the
    -- upstream service to allow or deny access.
    ngx.var.auth_token = res.header['Auth-Token']
  end
else
  ngx.log(ngx.DEBUG, "==== skipping GET /auth since auth_token is present: [" .. ngx.var.auth_token .. "]")
end
