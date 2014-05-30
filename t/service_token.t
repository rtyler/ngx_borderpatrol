use lib 'lib';
use Test::Nginx::Socket;

$ENV{TEST_NGINX_MEMCACHED_PORT} ||= 11211;

repeat_each(1);

plan tests => repeat_each() * (2 * blocks()) -3;

run_tests();

__DATA__

=== TEST 0: test getting service token with valid master token and valid service name
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
location = /session {
    internal;
    set $memc_key $arg_id;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}

location = /mastertoken {
    echo_status 200;
    echo '{smb: "tokentokentokentoken"}';
    echo_flush;
}

location /serviceauth { # under test
    content_by_lua_file '../../build/usr/share/borderpatrol/service_token.lua';
}

--- request eval
"POST /serviceauth
mastertoken=DEADBEEF&service=smb"
--- more_headers
Cookie: border_session=MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
Content-type: application/x-www-form-urlencoded

--- response_body_like
{smb: "tokentokentokentoken"}

--- error_code: 200

=== TEST 1: test attempt to get service token with valid master token and invalid service name
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
location = /session {
    internal;
    set $memc_key $arg_id;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}

location = /mastertoken {
    echo_status 400;
    echo_flush;
}

location /serviceauth { # under test
    content_by_lua_file '../../build/usr/share/borderpatrol/service_token.lua';
}

--- request eval
"POST /serviceauth
mastertoken=DEADBEEF&service=junkservice"
--- more_headers
Cookie: border_session=MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
Content-type: application/x-www-form-urlencoded

--- error_code: 400

=== TEST 2: test attempt to get service token with nil master token
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
location = /session {
    internal;
    set $memc_key $arg_id;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}

location = /mastertoken {
    echo_status 400;
    echo_flush;
}

location /serviceauth { # under test
    content_by_lua_file '../../build/usr/share/borderpatrol/service_token.lua';
}

--- request eval
"POST /serviceauth
service=junkservice"
--- more_headers
Cookie: border_session=MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
Content-type: application/x-www-form-urlencoded

--- error_code: 400

=== TEST 3: test attempt to get service token with valid master token but missing service name
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
location = /session {
    internal;
    set $memc_key $arg_id;
    memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
}

location = /mastertoken {
    echo_status 400;
    echo_flush;
}

location /serviceauth { # under test
    content_by_lua_file '../../build/usr/share/borderpatrol/service_token.lua';
}

--- request eval
"POST /serviceauth
service=junkservice"
--- more_headers
Cookie: border_session=MDEyMzQ1Njc4OTAxMjM0NQ**:1595116800:9Wc0CzZKO7Mq5Y2NbTaHrIp/gMg*
Content-type: application/x-www-form-urlencoded

--- error_code: 400


