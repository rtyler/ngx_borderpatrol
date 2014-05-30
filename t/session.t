use lib 'lib';
use Test::Nginx::Socket;

$ENV{TEST_NGINX_MEMCACHED_PORT} ||= 11211;

plan tests => $Test::Nginx::Socket::RepeatEach * 2 * blocks();

run_tests();

__DATA__

=== TEST 1: basic expiry
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
--- config
    location /exptime {
        echo 'flush_all';
        echo_location '/memc?cmd=flush_all';

        echo 'set foo BAR';
        echo_subrequest PUT '/memc?key=foo&exptime=1' -b BAR;

        echo 'get foo - 0 sec';
        echo_location '/memc?key=foo';
        echo;

        echo_blocking_sleep 1.1;

        echo 'get foo - 1.1 sec';
        echo_location '/memc?key=foo';
    }
    location /memc {
        echo_before_body "status: $echo_response_status";
        echo_before_body "exptime: $memc_exptime";

        set $memc_cmd $arg_cmd;
        set $memc_key $arg_key;
        set $memc_exptime $arg_exptime;

        memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
    }
--- request
    GET /exptime
--- response_body_like
^flush_all
status: 200
exptime: 
OK\r
set foo BAR
status: 201
exptime: 1
STORED\r
get foo - 0 sec
status: 200
exptime: 
BAR
get foo - 1\.1 sec
status: 404
exptime: 
<html>.*?404 Not Found.*$

=== TEST 2: set and reset exptime
--- config
    location /exptime {
        echo 'flush_all';
        echo_location '/memc?cmd=flush_all';

        echo 'set foo BAR';
        echo_subrequest PUT '/memc?key=foo&exptime=1' -b BAR;

        echo 'get foo - 0 sec';
        echo_location '/memc?key=foo';
        echo;

        echo 'set foo BAZ';
        echo_subrequest PUT '/memc?key=foo&exptime=2' -b BAR;

        echo_blocking_sleep 1;

        echo 'get foo - 1 sec';
        echo_location '/memc?key=foo';
        echo;

        echo_blocking_sleep 1.1;

        echo 'get foo - 2 sec';
        echo_location '/memc?key=foo';
    }
    location /memc {
        echo_before_body "status: $echo_response_status";
        echo_before_body "exptime: $memc_exptime";

        set $memc_cmd $arg_cmd;
        set $memc_key $arg_key;
        set $memc_exptime $arg_exptime;

        memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
    }
--- request
    GET /exptime
--- response_body_like
^flush_all
status: 200
exptime: 
OK\r
set foo BAR
status: 201
exptime: 1
STORED\r
get foo - 0 sec
status: 200
exptime: 
BAR
set foo BAZ
status: 201
exptime: 2
STORED\r
get foo - 1 sec
status: 200
exptime: 
BAR
get foo - 2 sec
status: 404
exptime: 
<html>.*?404 Not Found.*$

