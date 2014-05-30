This folder contains self-signed SSL key and certs which will be used for local testing with your browser:

Generate new ones via (won't be needed though):

    openssl genrsa -des3 -out server.key 1024
    openssl req -new -key server.key -out server.csr
    cp server.key server.key.org
    openssl rsa -in server.key.org -out server.key
    openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

Additional details can be found <a href="https://www.digitalocean.com/community/articles/how-to-create-a-ssl-certificate-on-nginx-for-ubuntu-12-04">here</a>.