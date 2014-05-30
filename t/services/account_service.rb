require 'sinatra'
require 'json'
require "net/http"
require "uri"

KEYMASTER_URI = 'http://localhost:9081/api/auth/service/v1/account_master_token.json'


post '/' do
  $stderr.write "apiserver #{request.url}\n"
  service = request['service']
  username = request['username']
  password = request['password']

  uri = URI.parse(KEYMASTER_URI)
  params = {'s'=> service, 'e' => username, 'p' => password}
  response = Net::HTTP.post_form(uri, params)
  $stderr.write "keymaster status was: #{response.code} response body was #{response.body}\n"
  if response.code == '200'
    $stderr.write "account service returning: #{response.body}\n"
    content_type :json
    response.body
  else
    $stderr.write "Unable to Authorize user!\n"
    halt 401, 'Unable to Authorize user!'
  end
end

get '/' do
  $stderr.write "apiserver #{request.url}\n"
  haml :login, :content_type => 'text/html'
end

get '/password' do
  $stderr.write "apiserver #{request.url}\n"
  haml :password, :content_type => 'text/html'
end

__END__

@@ layout
%html
  %head
  %title
    Account Service
  %body{:style => 'text-align: center'}
    = yield

@@ index
%h1 Welcome to the Account Service!
%a{:href => '/logout?destination=/b/'}
  logout

@@ loggedout
%h1 Oops, You are not logged in.
%a{:href => '/b/login'}
  login

@@ login
%h1
  ACCOUNT SERVICE LOGIN

%form{:action => "/", :method => 'post'}
  %label
    Username
    %input{:name => "username", :type => "text", :value => "user@example.com"}
  %br/
  %label
    Password
    %input{:name => "password", :type => "password", :value => "password"}
  %br/
  %input{:name => "service", :type => "hidden", :value => "smb"}
  %input{:type => "submit", :name => "login", :value => "login"}

@@ password
%h1
  THIS IS THE ACCOUNT MANAGEMENT PAGE

%form{:action => "/", :method => 'post'}
  %label
    Username
    %input{:name => "username", :type => "text", :value => "user@example.com"}
  %br/
  %label
    Password
    %input{:name => "password", :type => "password", :value => "password"}
  %br/
  %input{:name => "service", :type => "hidden", :value => "smb"}
  %input{:type => "submit", :name => "login", :value => "login"}