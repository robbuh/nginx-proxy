# nginx-proxy

## Reference guides

* [Minimal Nginx front end configuration for Plone on Ubuntu/Debian Linux](https://docs.plone.org/manage/deploying/front-end/nginx.html#minimal-nginx-front-end-configuration-for-plone-on-ubuntu-debian-linux)
* [Securing Plone-Sites with https and nginx](https://www.starzel.de/blog/securing-plone-sites-with-https-and-nginx)
* [Securing Plone Sites With Nginx and HTTPS/SSL](https://designinterventionsystems.com/plone-blog/securing-plone-sites-with-nginx-and-https-ssl)


## Add a self signed certificate for HTTPS connection

Go to nginx-proxy project folder e.g.:
```
$ cd mydir/nginx-proxy
```

Create a local-ssl directory in home folder
```
$ mkdir ~/local-ssl
```

### Become a Certificate Authority

Generate private key
```
$ openssl genrsa -des3 -out ~/local-ssl/myCA.key 2048
```

Generate root certificate
```
$ openssl req -x509 -new -nodes -key ~/local-ssl/myCA.key -sha256 -days 825 -out ~/local-ssl/myCA.pem

-----
Country Name (2 letter code) []: EU
State or Province Name (full name) []: Italy
...
```

###  Create CA-signed certs
Set var with www.your-domain.test you're playing with
```
$ NAME=plone.mysite.test
```

Generate a private key
```
$ openssl genrsa -out certs/$NAME.key 2048
```

Create a certificate-signing request

For Mac users: make sure to set the ```"Common Name"``` to the same as ```$NAME``` when it's asking for setup
```
$ openssl req -new -key certs/$NAME.key -out ~/local-ssl/$NAME.csr
```

Create a config file for the extensions

For Mac users: add ```extendedKeyUsage=serverAuth,clientAuth``` below ```basicConstraints=CA:FALSE```
```
$ >~/local-ssl/$NAME.ext cat <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
extendedKeyUsage=serverAuth,clientAuth
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = $NAME # Be sure to include the domain name here because Common Name is not so commonly honoured by itself
DNS.2 = www.$NAME # Optionally, add additional domains (I've added a www subdomain here)
IP.1 = 127.0.0.1 # Optionally, add an IP address (if the connection which you have planned requires it)
EOF
```

Create the signed certificate
```
$ openssl x509 -req -in ~/local-ssl/$NAME.csr -CA ~/local-ssl/myCA.pem -CAkey ~/local-ssl/myCA.key -CAcreateserial -out certs/$NAME.crt -days 3650 -sha256 -extfile ~/local-ssl/$NAME.ext
```

For Mac users - Add certificate in Keychains.
```
$ sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/$NAME.crt
```

Don't forget to [trust the new certificate throught Keychains Access app](https://support.apple.com/en-gb/guide/keychain-access/kyca11871/mac) if necessary

### Check your self signed certificate
```
$ openssl verify -CAfile ~/local-ssl/myCA.pem -verify_hostname $NAME certs/$NAME.crt
```
