# vim: ft=ruby

ROOT_PATH    = Dir.pwd
TEST_PATH    = File.join(ROOT_PATH, 't')
SERVICE_PATH = File.join(TEST_PATH, 'services')
SERVER_PATH  = File.join(TEST_PATH, 'servroot')
LOG_PATH     = File.join(SERVER_PATH, 'logs')

GROUP_NAME = 'borderpatrol'

# Watch the api service
God.watch do |w|
  w.name = 'api_service'
  w.group = GROUP_NAME
  w.dir = SERVICE_PATH
  w.start = 'bundle exec shotgun api_service.rb -p 9082'
  w.log = File.join(LOG_PATH, 'api_service.out')
  w.keepalive
end

# Watch the 2nd api service
God.watch do |w|
  w.name = 'api_service2'
  w.group = GROUP_NAME
  w.dir = SERVICE_PATH
  w.start = 'bundle exec shotgun api_service2.rb -p 9083'
  w.log = File.join(LOG_PATH, 'api_service2.out')
  w.keepalive
end

# Watch the account service
God.watch do |w|
  w.name = 'account_service'
  w.group = GROUP_NAME
  w.dir = SERVICE_PATH
  w.start = 'bundle exec shotgun account_service.rb -p 9084'
  w.log = File.join(LOG_PATH, 'account_service.out')
  w.keepalive
end

# Watch the token server
God.watch do |w|
  w.name = 'token_service'
  w.group = GROUP_NAME
  w.dir = SERVICE_PATH
  w.start = 'bundle exec shotgun auth_service.rb -p 9081'
  w.log = File.join(LOG_PATH, 'token_service.out')
  w.keepalive
end

God.watch do |w|
  w.name = 'memcache'
  w.group = GROUP_NAME
  w.dir = SERVER_PATH
  w.start = 'memcached -vvv'
  w.log = File.join(LOG_PATH, 'memcached.out')
  w.keepalive
end

God.watch do |w|
  w.name = 'nginx'
  w.group = GROUP_NAME
  w.dir = SERVER_PATH
  w.start = "#{ROOT_PATH}/build/usr/sbin/borderpatrol -g 'error_log #{LOG_PATH}/error.log;' -p #{SERVER_PATH} -c #{ROOT_PATH}/build/etc/borderpatrol/sites-available/borderpatrol.conf.sample"
  w.log = File.join(LOG_PATH, 'nginx.out')
  w.keepalive
end


