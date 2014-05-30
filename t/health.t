use lib 'lib';
use Test::Nginx::Socket;

$ENV{TEST_NGINX_MEMCACHED_PORT} ||= 11211;

repeat_each(1);

plan tests => repeat_each() * (1 * blocks());

run_tests();

__DATA__

=== TEST 1: heath controller
--- main_config
--- http_config
lua_package_path "./build/usr/share/borderpatrol/?.lua;./build/usr/share/lua/5.1/?.lua;;";
lua_package_cpath "./build/usr/lib/lua/5.1/?.so;;";
--- config
    location = /session {
      set $memc_key $arg_id;
      set $memc_exptime 10;

      memc_cmds_allowed get set add delete;
      memc_pass 127.0.0.1:$TEST_NGINX_MEMCACHED_PORT;
    }

    location /health {
        content_by_lua_file '../../build/usr/share/borderpatrol/health_check.lua';
    }
--- request
    GET /health
--- error_code: 200
