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

=== TEST 1: test successful redirect
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
location = /session {
    internal;
    set $memc_key $arg_id;
    set $memc_value $arg_val;
    set $memc_exptime $arg_exptime;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}
location /redirect {
    content_by_lua_file '../../build/usr/share/borderpatrol/redirect.lua';
}

--- request eval
"POST /redirect"
--- more_headers
Content-type: application/x-www-form-urlencoded
--- error_code: 302
--- response_headers_like
Location: http://localhost(?::\d+)?/account$

=== TEST 2: test memcached down
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
location /redirect {
    content_by_lua_file '../../build/usr/share/borderpatrol/redirect.lua';
}
--- request eval
"POST /redirect"
--- more_headers
Content-type: application/x-www-form-urlencoded
--- error_code: 502

