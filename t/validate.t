use lib 'lib';
use Test::Nginx::Socket;

$ENV{TEST_NGINX_MEMCACHED_PORT} ||= 11211;

repeat_each(1);

plan tests => repeat_each() * (2 * blocks()) - 1;

run_tests();

__DATA__


=== TEST 1: test valid sessionid and valid auth token
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
init_by_lua 'service_mappings = {auth="smb", s="flexd"}';
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
    echo_subrequest POST '/memc_setup?key=BPSID_MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*' -b '{"auth_service": "aaa","service_tokens": {"smb": "bbb"}}';
}
location = /session {
    internal;
    set $memc_key $arg_id;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}

location = /validate {
    content_by_lua_file '../../build/usr/share/borderpatrol/validate.lua';
}

location /auth { # under test
    echo_location /setup;
    echo_location /validate;
    echo $echo_response_status;
}
--- request
GET /auth
--- more_headers
Cookie: border_session=MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
--- response_body_like
OK\r
STORED\r
STORED\r
STORED\r
200

=== TEST 2: test valid sessionid and but no token stored
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
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
    echo_subrequest POST '/memc_setup?key=BPS1' -b 'mysecret:1234567890';
}
location = /session {
    internal;
    set $memc_key $arg_id;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}

location = /validate {
    content_by_lua_file '../../build/usr/share/borderpatrol/validate.lua';
}

location /auth { # under test
    echo_location /setup;
    echo_location /validate;
    echo $echo_response_status;
}
--- request
GET /auth
--- more_headers
Cookie: border_session=MDEyMzQ1Njc4OTAxMjM0NQ**:Mv+cEjtny9UIrLFYBKFKWQoBvPk*
--- response_body_like
OK\r
STORED\r
STORED\r
.*401 Authorization Required.*

=== TEST 3: test missing sessionid
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
--- config
location /auth { # under test
    content_by_lua_file '../../build/usr/share/borderpatrol/validate.lua';
}
--- request
GET /auth
--- error_code: 401

=== TEST 4: test valid sessionid and valid auth token
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
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
    echo_subrequest POST '/memc_setup?key=BPS1' -b 'mysecret:1234567890';
}
location = /session {
    internal;
    set $memc_key $arg_id;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}

location = /validate {
    content_by_lua_file '../../build/usr/share/borderpatrol/validate.lua';
}

location /auth { # under test
    echo_location /setup;
    echo_location /validate;
    echo $echo_response_status;
}
--- request
GET /auth
--- more_headers
Cookie: border_session==MTExMTExMTExMTExMTExMQ**:Mv+cEjtny9UIrLFYBKFKWQoBvPk*
--- response_body_like
OK\r
STORED\r
STORED\r
.*401 Authorization Required.*
