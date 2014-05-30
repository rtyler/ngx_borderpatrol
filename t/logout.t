use lib 'lib';
use Test::Nginx::Socket;

$ENV{TEST_NGINX_MEMCACHED_PORT} ||= 11211;

repeat_each(1);

plan tests => repeat_each() * (2 * blocks());

run_tests();

__DATA__

=== TEST 1: test logout w/o destination and w/o session_id
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
--- config
location /logout { # under test
    content_by_lua_file '../../build/usr/share/borderpatrol/logout.lua';
}
--- request
GET /logout
--- error_code: 302
--- response_headers_like: Location: http://localhost(?::\d+)?/$

=== TEST 2: test logout w/ relative destination and w/o session_id
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
--- config
location /logout { # under test
    content_by_lua_file '../../build/usr/share/borderpatrol/logout.lua';
}
--- request
GET /logout?destination=/somepath
--- error_code: 302
--- response_headers_like: Location: http://localhost(?::\d+)?/somepath$

=== TEST 3: test logout w/ absolute destination and w/o session_id
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
--- config
location /logout { # under test
    content_by_lua_file '../../build/usr/share/borderpatrol/logout.lua';
}
--- request
GET /logout?destination=http://www.evil.org
--- error_code: 302
--- response_headers_like: Location: http://localhost(?::\d+)?/$

=== TEST 4: test logout w/ session_id
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
--- config
location /logout { # under test
    content_by_lua_file '../../build/usr/share/borderpatrol/logout.lua';
}
location /session_delete { # memcached
    internal;
    echo_status 400; # simulates successful write into memcached
    echo_flush;
}
--- request
GET /logout
--- more_headers
Cookie: border_session=wfxLNdl2BrLN9NVuQ9_wiA**:4lcaas0Onjxsn2D6kDVPTw**
--- error_code: 302
--- response_headers_like
Set-Cookie: border_session=; path=/; expires=.+GMT$
--- response_headers_like: Location: http://localhost(?::\d+)?/$
