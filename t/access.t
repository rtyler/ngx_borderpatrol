use lib 'lib';
use Test::Nginx::Socket;

$ENV{TEST_NGINX_MEMCACHED_PORT} ||= 11211;

plan tests => $Test::Nginx::Socket::RepeatEach * 2 * blocks();

run_tests();

__DATA__

=== TEST 1: test w/ auth-token present in client request
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";

upstream b {
  server 127.0.0.1:$TEST_NGINX_SERVER_PORT; # self
}

--- config
location /testpath {
    echo_status 200;
    echo_duplicate 1 $echo_client_request_headers;
    echo 'everything is ok';
    echo_flush;
}
location /auth {
    echo_status 200;
    echo_flush;
}
location /b/testpath {
    set $auth_token $http_auth_token;
    access_by_lua_file '../../build/usr/share/borderpatrol/access.lua';
    proxy_set_header auth-token $auth_token;

    # http://hostname/upstream_name/uri -> http://upstream_name/uri
    rewrite ^/([^/]+)/?(.*)$ /$2 break;
    proxy_pass         http://$1;
    proxy_redirect     off;
    proxy_set_header   Host $host;
}
--- request
GET /b/testpath
--- more_headers
auth-token: tokentokentokentoken
--- error_code: 200
--- response_body_like
auth-token: tokentokentoken.+everything is ok$

=== TEST 2: test w/o auth-token not present in client request but with valid session
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
init_by_lua 'service_mappings = {b="smb",s="flexd"}';
upstream b {
  server 127.0.0.1:$TEST_NGINX_SERVER_PORT; # self
}
--- config
location /testpath {
    echo_status 200;
    echo_duplicate 1 $echo_client_request_headers;
    echo 'everything is ok';
    echo_flush;
}
location /auth {
    internal;
    echo_status 200;
    more_set_headers 'Auth-Token: tokentokentokentoken';
    echo_flush;
}
location /b/testpath {
    set $auth_token $http_auth_token;
    access_by_lua_file '../../build/usr/share/borderpatrol/access.lua';
    proxy_set_header auth-token $auth_token;

    # http://hostname/upstream_name/uri -> http://upstream_name/uri
    rewrite ^/([^/]+)/?(.*)$ /$2 break;
    proxy_pass         http://$1;
    proxy_redirect     off;
    proxy_set_header   Host $host;
}
--- request
GET /b/testpath
--- more_headers
Cookie: border_session=this-is-a-session-id # not checked here!
--- error_code: 200
--- response_body_like
auth-token: tokentokentoken.+everything is ok$