require 'sinatra'

["/", "/first/second"].each do |path|
  get path do
    token = request.env['HTTP_AUTH_TOKEN']
    $stderr.write "apiserver #{request.url} token = #{token}\n"

    if token != 'LIVEKALESMB'
      halt 401, 'Ooops, request not authenticated. Did you login?'
      #haml :loggedout, :content_type => 'text/html'
    else
      haml :index, :content_type => 'text/html'
    end
  end
end

get '/login' do
  $stderr.write "apiserver #{request.url}\n"
  haml :login, :content_type => 'text/html'
end

get '/unrestricted' do
  'This is an unsecured resource.'
end

get '/unrestricted/1' do
  'This is an unsecured resource.'
end

__END__

@@ layout
%html
  %head
  %title
    Device Login
  %body{:style => 'text-align: center'}
    = yield

@@ index
%h1 Welcome to the First Server!
%a{:href => '/logout?destination=/b/'}
  logout

@@ loggedout
%h1 Oops, You are not logged in.
%a{:href => '/b'}
  login