-- session_id module to issue and validate signed session ids
local crypto = require("crypto")

local module = {}

-- record expiration time in memcached
local EXPTIME = 60 * 60
local EXPTIME_TMP = 60 * 60 * 24 * 7

-- defines how often secrets will be rotated
local SECRETS_EXP_INTERVAL = 60 * 60 * 24

-- internal session cookie lifetime to prevent unbound sessions
local SESSION_COOKIE_LIFETIME = SECRETS_EXP_INTERVAL * 2

-- lease lifetime (short-living)
local SECRETS_LEASE_INTERVAL = 5

-- signature length - used for basic validation
local HMAC_SHA1_SIGN_LENGTH = 20

-- number of random bytes generated for session ids
local DATA_LENGTH = 16

-- secret length - we keep 2 secrets in memory
local KEY_LENGTH = 64

-- stores the time when to check whether we need to rotate secrets
local ts_next_refresh = -1

-- encode string and make it url-safe
local function encode(str, urlsafe)

  local enc_str = ngx.encode_base64(str)
  if urlsafe then
    enc_str =  string.gsub(enc_str, "+", "-") -- plus -> dash
    enc_str =  string.gsub(enc_str, "/", "_") -- slash to underscore
    enc_str =  string.gsub(enc_str, "=", "*") -- equal to star
  end

  return enc_str
end

-- decode string
-- returns empty string if data is not base64 encoded
local function decode(str, urlsafe)

  local dec_str = str
  if urlsafe then
    dec_str =  string.gsub(dec_str, "-", "+") -- plus -> dash
    dec_str =  string.gsub(dec_str, "_", "/") -- slash to underscore
    dec_str =  string.gsub(dec_str, "*", "=") -- equal to star
  end

  return ngx.decode_base64(dec_str)
end

-- serializes secret into string
local function serialize_secret(secret)
  local str
  if secret and type(secret) == "table" then
    str = secret.data .. ":" .. secret.ts
  end
  return str
end

-- deserializes secret string into a table
local function deserialize_secret(str)
  local secret
  if str and type(str) == "string" then
    local startPos, endPos, data, ts = string.find(str, "(.+):(.+)")
    secret = {}
    secret.data = data
    secret.ts = tonumber(ts)
  end
  return secret
end

--
-- function to save secrets in SHM and memcached
-- secret1 mandatory
-- secret2 optional
--
local function save_secrets(secret1, secret2)

  local secret1_str = serialize_secret(secret1)
  local secret2_str = serialize_secret(secret2)

  -- persist in memcached
  local res = ngx.location.capture('/session?id=BPS1',
    { body = secret1_str, method = ngx.HTTP_PUT })
  if res.status ~= ngx.HTTP_CREATED then
    ngx.log(ngx.WARN, "==== failed to persist secret1 " .. secret1_str .. " " .. res.status)
  else
    ngx.log(ngx.DEBUG, "==== secret1 persisted successfully " .. secret1_str .. " " .. res.status)
  end

  -- secret2 is optional
  if secret2_str then
    -- persist in memcached
    res = ngx.location.capture('/session?id=BPS2',
      { body = secret2_str, method = ngx.HTTP_PUT })
    if res.status ~= ngx.HTTP_CREATED then
      ngx.log(ngx.WARN, "==== failed to persist secret2 " .. secret2_str .. " " .. res.status)
    else
      ngx.log(ngx.DEBUG, "==== secret2 persisted successfully " .. secret2_str .. " " .. res.status)
    end
  end
end

--
-- function to retrieve secrets, secret1 is current, secret2 is rotated
--
local function get_secrets()

  local secret1, secret2

  local res1, res2 = ngx.location.capture_multi{
    { '/session?id=BPS1', { method = ngx.HTTP_GET } },
    { '/session?id=BPS2', { method = ngx.HTTP_GET } },
  }

  if res1.status >=  ngx.HTTP_INTERNAL_SERVER_ERROR then
    ngx.log(ngx.ERR, "==== could not fetch secrets - memcached down?")
    ngx.exit(res1.status)
  end

  if res1.status == ngx.HTTP_OK then
    secret1 = deserialize_secret(res1.body)
    ts_next_refresh = secret1.ts + SECRETS_EXP_INTERVAL -- update to the time when the cookie expired
  elseif res1.status == ngx.HTTP_NOT_FOUND then
    ngx.log(ngx.ERR, "==== secret1 not found - did memcached just restart?")
    -- trigger key refresh in case memcached got restarted
    ts_next_refresh = 0
  else
    ngx.log(ngx.ERR, "==== failed to retrieve secret1 " .. res1.status)
  end

  if res2.status == ngx.HTTP_OK then
    secret2 = deserialize_secret(res2.body)
  else
    ngx.log(ngx.WARN, "==== failed to retrieve secret2 - that's prob okay in case secrets have not been rotated yet. " .. res2.status)
  end

  return secret1, secret2
end

--
-- function to refresh secrets for hmac signing
--
local function refresh_keys_if_required()

  -- initial check
  if (ts_next_refresh == -1) then
    local secret1, secret2 = get_secrets()
    if secret1 then
      ts_next_refresh = secret1.ts + SECRETS_EXP_INTERVAL
    else
      ts_next_refresh = 0
    end
  end

  if (ngx.time() > ts_next_refresh) then
    ngx.log(ngx.DEBUG, "==== it's time to refresh keys...")

    local res = ngx.location.capture("/session?id=BP_LEASE", { method = ngx.HTTP_GET })
    if res.status == ngx.HTTP_NOT_FOUND then

      local res = ngx.location.capture("/session?id=BP_LEASE&exptime=" .. SECRETS_LEASE_INTERVAL,
        { body = "1", method = ngx.HTTP_POST })
      if res.status == ngx.HTTP_CREATED then

        local secret1, secret2 = get_secrets()

        -- generate new secret
        local new_secret = {}
        new_secret.data = ngx.encode_base64(crypto.rand.bytes(KEY_LENGTH))
        new_secret.ts = ngx.time();

        -- persist new secrets
        save_secrets(new_secret,secret1)

        res = ngx.location.capture("/session_delete?id=BP_LEASE", { method = ngx.HTTP_GET })
        ngx.log(ngx.DEBUG, "==== lease deleted " .. res.status)

        ts_next_refresh = new_secret.ts + SECRETS_EXP_INTERVAL

      elseif res.status == ngx.HTTP_OK then
        ngx.log(ngx.DEBUG, "=== lease to update keys already taken - concurrent update?")
      else
        ngx.log(ngx.WARN, "==== failed to acquire lease " .. res.status)
      end
    else
      ngx.log(ngx.WARN, "==== refresh keys not needed yet")
    end
  end
end

--
-- generate session_id
--
local function generate()

  refresh_keys_if_required()

  -- create 128 bit of random bytes
  local data = crypto.rand.bytes(DATA_LENGTH)
  local ts = ngx.time()
  local secret1, secret2 = get_secrets()

  -- we could also use 'crypto' for 'digesting' but benchmark shows it's slightly
  -- slower: crypto.hmac.digest("sha1", data, secret1, true)
  local signature = ngx.hmac_sha1(secret1.data, data .. ts)
  local session_id = encode(data, true) .. ":" .. ts .. ":" .. encode(signature, true)

  return session_id
end

--
-- function to validate session_id
--
local function is_valid(session_id)

  refresh_keys_if_required()

  -- parse session id
  local startPos, endPos, data, ts, signature = string.find(session_id, "(.+):(.+):(.+)")
  ts = tonumber(ts)

  -- check for the obvious
  if not data or not signature or not ts then
    return false
  end

  -- check whether the cookie expired already
  if ngx.time() > ts + SESSION_COOKIE_LIFETIME then
    return false
  end

  -- decode
  data = decode(data, true)
  signature = decode(signature, true)

  -- check whether data or signature became nil (happens in case it couldn't be decoded properly)
  if not data or #data ~= DATA_LENGTH or not signature or #signature ~= HMAC_SHA1_SIGN_LENGTH then
    return false
  end

  -- re-compute signature
  local secret1, secret2 = get_secrets()
  if not secret1 then
     -- did memcache just restarted?
     return false
  else
    local computed_signature = ngx.hmac_sha1(secret1.data, data .. ts)

    local match = computed_signature == signature
    if not match and secret2 then
      -- fallback - check with secret2
      -- TBD: issue fresh session cookie to prevent session loss after secrets
      -- get rotated, a bit overkill for now
      computed_signature = ngx.hmac_sha1(secret2.data, data .. ts)
      match = computed_signature == signature
    end

    return match
  end
end

module.generate = generate
module.is_valid = is_valid
module.EXPTIME = EXPTIME
module.EXPTIME_TMP = EXPTIME_TMP

return module