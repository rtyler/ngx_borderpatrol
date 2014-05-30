require 'sinatra'
require 'json'

REQUIRED_PARAMS = [:e, :p, :s]

# There are 2 possible scenarios
# Get a service token by itself
# wget -S --post-data "e=user@example.com&p=password&s=smb" http://localhost:9081/api/auth/service/v1/account_master_token.json

# Get a list of service tokens (using a username and password)
# wget -S --post-data "e=user@example.com&p=password&s=smb,flexd" http://localhost:9081/api/auth/service/v1/account_master_token.json
post '/api/auth/service/v1/account_master_token.json' do
  $stderr.write "apiserver #{request.url} params = #{params}\n"
  REQUIRED_PARAMS.each do |r|
    (status 500 and return) unless params.include?(r.to_s)
  end

  if params[:e] == 'user@example.com' && params[:p] == 'password'
    resp = build_tokens(params[:s])
    resp['auth_service'] = 'DEADBEEF'
    content_type :json
    resp.to_json
  else
    status 401
  end
end

post '/api/auth/service/v1/account_token.json' do
  $stderr.write "authserver #{request.url}\n"
  $stderr.write "authserver master token #{request.env['HTTP_AUTH_TOKEN']}\n"
  (status 500 and return) unless params.include?('services')
  master_token = request.env['HTTP_AUTH_TOKEN']
  (status 401 and return) unless master_token == 'DEADBEEF'
  (status 401 and return) unless params[:services] !~ /auth_service/
  $stderr.write "authserver service =  #{params.inspect}\n"
  resp = build_tokens(params[:services])
  $stderr.write "authserver RETURNING #{resp.inspect}\n"
  content_type :json
  resp.to_json
end

def build_tokens(services)
  resp = {'service_tokens' => {}}
  $stderr.write resp
  services.split(',').map do |service_name|
    resp['service_tokens'][service_name] = "LIVEKALE#{service_name.upcase}"
  end
  resp
end
