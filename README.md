# BorderPatrol for Nginx

BorderPatrol is an nginx module to perform authentication and session management at the border of your network.

BorderPatrol makes the assumption that you have some set of services that require authentication and a service that
hands out tokens to clients to access that service. You may not want those tokens to be sent across the internet, even
over SSL, for a variety of reasons. To this end, BorderPatrol maintains a lookup table of session-id to auth token
in memcached.

## Overview Diagram

            +-------------+
            |   BROWSER   |
            +--+----------+
               |       ^
          REQ  |       |  RESP
               |       |
               v       |       SVC
          +------------+----+  CALL  +-------------------------------+
          |                 +------->|     SERVICE A REQUIRING       |
          |                 |<-------|       AUTHENTICATION          |
          |                 |        +-------------------------------+
          |      NGINX      |
          |                 |        +-------------------------------+
          |                 +------->|     SERVICE B REQUIRING       |
          |                 |<-------|       AUTHENTICATION          |
          +-----------------+        +-------------------------------+
              | ^       | ^
       CACHE  | |       | |  AUTH
      LOOKUP  | |       | |  LOOKUP
              v |       v |
    +-----------+-+   +---+----------+
    |   SESSION   |   |     AUTH     |
    |    STORE    |   |   SERVICE    |
    +-------------+   +--------------+

## Use cases

**Assumption:** All content to be access via BorderPatrol requires authentication

There are three primary use cases for BorderPatrol:

* A client has an auth token in the session store and the request is forwarded to the downstream service -or-
* A client does not have an auth_token for the specified service but has a master token, a call to the auth service will be made to get a service token for the downstream service -or-
* A client does not have an auth_token, and the client is redirected to a login page which posts back to nginx, performs an auth service lookup (and returns a master token and a service token from the auth service) and, on success, creates an entry in the session store for subsequent requests.

### Use Case 1: Authorized Access

* Client requests a protected resource via BorderPatrol
* BorderPatrol looks up the session_id from the HTTP request in the SessionStore
* If service token present, BorderPatrol sets the Auth-Token header to the service token and allows the request to continue to the protected resource

### Use Case 2: Unauthorized Access

* Client requests a protected resource via BorderPatrol
* BorderPatrol looks up the session_id from the HTTP request in the SessionStore
* Record exists in cache and there is a master token but no service token for specified downstream service
* A call is made to the Auth Service using the master token to get a service token
* BorderPatrol updates the session_id/{master_token, service_token_1, service_token_2...} pair in the SessionStore with appropriate expiry
* BorderPatrol redirects with the appropriate service Auth-Token header to the protected resource

### Use Case 3: Unauthorized Access

* Client requests a protected resource via BorderPatrol
* BorderPatrol looks up the session_id from the HTTP request in the SessionStore
* If there is a cache miss, BorderPatrol serves up a login page
* On submittal, this posts to the AuthService (via BorderPatrol)
* On successful authentication (which returns a master token and a service token for the downstream service), the AuthService sets the Auth-Token header
* BorderPatrol sets the session_id/{master_token, service_token} pair in the SessionStore with appropriate expiry
* BorderPatrol redirects with the appropriate service Auth-Token header to the protected resource

### Caching detail

The tokens cached in the session store are a string representation of a JSON structure as follows.

{
  "master_token" : "MMM",
  "service_tokens" : { "service_a": "AAA", "service_b": "BBB" }
}

The token that has the key of 'master_token' is the Master Token, and can be used to make a call to the Auth Service to get other service tokens.
Service Tokens have a key name that corresponds to the name of the downstream service.


### Installation

#### Darwin

* get homebrew (http://mxcl.github.io/homebrew/)
* brew install luarocks
* brew install pcre
* brew install lua
* brew install luajit
* make

#### Linux
* apt-get install luarocks
* make

### Running unit tests

You'll need the Test::Nginx CPAN module.

* cpan install Test::Nginx
* make test

### Running full mock services locally

* bundle install
* make mocktest
* In a browser, hit https://localhost:4443/b/

### Additional Notes

make mocktest uses God to run 4 processes, on the following ports
4443 Mock BorderPatrol
9081 Mock Authorization service
9082 Mock downstream service A
9083 Mock downstream service B

Once you stop Mocktest, manually kill the processes above
