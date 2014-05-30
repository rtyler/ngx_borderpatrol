use lib 'lib';
use Test::Nginx::Socket;

$ENV{TEST_NGINX_MEMCACHED_PORT} ||= 11211;

repeat_each(1);

plan tests => repeat_each() * (2 * blocks()) - 1;

run_tests();

__DATA__

=== TEST 0: initialize memcached
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
init_by_lua 'service_mappings = {b="smb", s="flexd"}';
--- config
location /memc_setup {
    internal;
    set $memc_cmd $arg_cmd;
    set $memc_key $arg_key;

    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location = /setup {
    # clear
    echo_subrequest GET '/memc_setup?cmd=flush_all';
    echo_subrequest POST '/memc_setup?key=BP_LEASE' -b '1';

    echo_subrequest POST '/memc_setup?key=BPS1' -b 'mysecret:1595116800';
}
--- request
GET /setup
--- more_headers
Content-type: application/x-www-form-urlencoded
--- error_code: 200
--- response_body_like
OK\r
STORED\r
STORED\r

=== TEST 1: test successful login
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
init_by_lua 'service_mappings = {b="smb", s="flexd"}';
--- config
location /memc_setup {
    internal;
    set $memc_cmd $arg_cmd;
    set $memc_key $arg_key;

    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location = /setup {
    # clear
    echo_subrequest GET '/memc_setup?cmd=flush_all';
    echo_subrequest POST '/memc_setup?key=BP_LEASE' -b '1';
    echo_subrequest POST '/memc_setup?key=BPS1' -b 'mysecret:1595116800';
    echo_subrequest POST '/memc_setup?key=BP_URL_SID_MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*' -b '/b';
    echo_status 200;
}
location = /session {
    internal;
    set $memc_key $arg_id;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location /authorize { # under test
    content_by_lua_file '../../build/usr/share/borderpatrol/authorize.lua';
}
location /account {
    internal;
    echo_status 200;
    echo '{"auth_service": "tokentokentokentoken", "service_tokens": {"smb": "tokentokentokentoken"}}';
    echo_flush;
}
--- request eval
["GET /setup", "POST /authorize
    username=foo&password=bar"]
--- more_headers
Content-type: application/x-www-form-urlencoded
Cookie: border_session=MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
---- response_headers_like
Set-Cookie: border_session=.+:.+; path=/; HttpOnly; Secure;$
Location: http://localhost(?::\d+)?/b$
--- error_code eval
[200,302]

=== TEST 2: test unsuccessful login
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
init_by_lua 'service_mappings = {b="smb", s="flexd"}';
--- config
location /memc_setup {
    internal;
    set $memc_cmd $arg_cmd;
    set $memc_key $arg_key;

    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location = /setup {
    # clear
    echo_subrequest GET '/memc_setup?cmd=flush_all';
    echo_subrequest POST '/memc_setup?key=BP_LEASE' -b '1';
    echo_subrequest POST '/memc_setup?key=BPS1' -b 'mysecret:1595116800';
    echo_subrequest POST '/memc_setup?key=BP_URL_SID_MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*' -b '/b';
    echo_status 200;
}
location = /session {
    internal;
    set $memc_key $arg_id;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location /authorize { # under test
    content_by_lua_file '../../build/usr/share/borderpatrol/authorize.lua';
}
location /account {
    internal;
    echo_status 403;
    echo_flush;
}
--- request eval
["GET /setup", "POST /authorize
    username=foo&password=bar"]
--- more_headers
Content-type: application/x-www-form-urlencoded
Cookie: border_session=MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
---- response_headers_like
Set-Cookie: border_session=.+:.+; path=/; HttpOnly; Secure;$
Location: http://localhost(?::\d+)?/b$
--- error_code eval
[200,302]

=== TEST 3: test failed login with memcached down
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
init_by_lua 'service_mappings = {b="smb", s="flexd"}';
--- config
location /memc_setup {
    internal;
    set $memc_cmd $arg_cmd;
    set $memc_key $arg_key;

    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location /session { # memcached
    internal;
    echo_status 502; # simulate memcached down
    echo_flush;
}
location /authorize { # under test
    content_by_lua_file '../../build/usr/share/borderpatrol/authorize.lua';
}
location /account {
    internal;
    echo_status 200;
    echo '{"auth_service": "tokentokentokentoken", "service_tokens": {"smb": "tokentokentokentoken"}}';
    echo_flush;
}
--- request eval
"POST /authorize
username=foo&password=bar"
--- more_headers
Content-type: application/x-www-form-urlencoded
Cookie: border_session=MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
---- response_headers_like
Set-Cookie: border_session=.+:.+; path=/; HttpOnly; Secure;$
Location: http://localhost(?::\d+)?/b$
--- error_code: 502

=== TEST 4: test failed login with Account Service down
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
init_by_lua 'service_mappings = {b="smb", s="flexd"}';
--- config
location /memc_setup {
    internal;
    set $memc_cmd $arg_cmd;
    set $memc_key $arg_key;

    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location = /setup {
    # clear
    echo_subrequest GET '/memc_setup?cmd=flush_all';
    echo_subrequest POST '/memc_setup?key=BP_LEASE' -b '1';
    echo_subrequest POST '/memc_setup?key=BPS1' -b 'mysecret:1595116800';
    echo_subrequest POST '/memc_setup?key=BP_URL_SID_MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*' -b '/b';
    echo_status 200;
}
location = /session {
    internal;
    set $memc_key $arg_id;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location /authorize { # under test
    content_by_lua_file '../../build/usr/share/borderpatrol/authorize.lua';
}
location /account {
    internal;
    echo_status 500;
    echo_flush;
}
--- request eval
["GET /setup", "POST /authorize
    username=foo&password=bar"]
--- more_headers
Content-type: application/x-www-form-urlencoded
Cookie: border_session=MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
---- response_headers_like
Set-Cookie: border_session=.+:.+; path=/; HttpOnly; Secure;$
Location: http://localhost(?::\d+)?/b$
--- error_code eval
[200,302]

=== TEST 5: test invalid service url
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
init_by_lua 'service_mappings = {b="smb", s="flexd"}';
--- config
location /memc_setup {
    internal;
    set $memc_cmd $arg_cmd;
    set $memc_key $arg_key;

    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location = /setup {
    # clear
    echo_subrequest GET '/memc_setup?cmd=flush_all';
    echo_subrequest POST '/memc_setup?key=BP_LEASE' -b '1';
    echo_subrequest POST '/memc_setup?key=BPS1' -b 'mysecret:1595116800';
    echo_subrequest POST '/memc_setup?key=BP_URL_SID_MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*' -b '/x';
    echo_status 200;
}
location = /session {
    internal;
    set $memc_key $arg_id;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location /authorize { # under test
    content_by_lua_file '../../build/usr/share/borderpatrol/authorize.lua';
}
location /account {
    internal;
    echo_status 403;
    echo_flush;
}
--- request eval
["GET /setup", "POST /authorize
    username=foo&password=bar"]
--- more_headers
Content-type: application/x-www-form-urlencoded
Cookie: border_session=MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
---- response_headers_like
Set-Cookie: border_session=.+:.+; path=/; HttpOnly; Secure;$
Location: http://localhost(?::\d+)?/b$
--- error_code eval
[200,302]
