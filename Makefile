MAKEFLAGS += --no-print-directory
.DEFAULT_GOAL := help
SHELL := /bin/bash

# Identify certs folders
HOME_DIR := $${HOME}
SSL_DIR := "${HOME_DIR}/local-ssl"
CERTS_DIR = "certs"

# Identify certs files
myCA.key = "myCA.key"
myCA.pem = "myCA.pem"



.PHONY: ssl-dir
ssl-dir:
	@if [[ ! -d ${SSL_DIR} ]]; then \
		mkdir ${SSL_DIR}; \
	fi;
	@echo "Local folder ${SSL_DIR} has been created";

.PHONY: CA-private-key
CA-private-key:
	@if [[ ! -f ${SSL_DIR}/${myCA.key} ]]; then \
		openssl genrsa -des3 -out /${SSL_DIR}/${myCA.key} 2048; \
	fi;
	@echo "Certificate Authority private key has been generated";

.PHONY: CA-root-cert
CA-root-cert:
	@if [[ ! -f ${SSL_DIR}/${myCA.pem} ]]; then \
		echo "Please fill at least 'Country Name' and 'State or Province Name' questions"; \
		openssl req -x509 -new -nodes -key ${SSL_DIR}/${myCA.key} -sha256 -days 825 -out ${SSL_DIR}/${myCA.pem}; \
	fi;
	@echo "Certificate Authority root certificate has been generated";

.PHONY: CA-signed-certs_create
 CA-signed-certs_create:
	@read -p "Enter the domain name you want to add (e.g. mydomain.com) :" domain; \
	read -p "Enter an ip address (leave blank for default 127.0.0.1) :" ipaddress; \
	if [ ! "$$ipaddress" ]; then \
		ipaddress='127.0.0.1'; \
	fi; \
	if [ ! "$$domain" ]; then \
		echo "Please set your domain name"; \
		exit 0; \
	else \
		echo "Generate a private key"; \
		openssl genrsa -out ${CERTS_DIR}/$$domain.key 2048; \
		echo "Create a certificate-signing request"; \
		echo -e "\a"; \
		echo "ALERT! For Mac users: make sure to set the 'Common Name' to the same as domain name setted (in your case: $$domain) when it's asking for setup"; \
		echo -e "\a"; \
		openssl req -new -key ${CERTS_DIR}/$$domain.key -out ${SSL_DIR}/$$domain.csr; \
		echo "Create a config file for the extensions"; \
		sed -e "s/DOMAIN_NAME/$$domain/g" -e "s/IP_ADDRESS/$$ipaddress/g" templates/certificate-extension.conf > ${SSL_DIR}/$$domain.ext; \
		echo -e "\a"; \
		echo "ALERT! For Not Mac users you can comment line 'extendedKeyUsage=serverAuth,clientAuth' in newly created file ${SSL_DIR}/$$domain.ext"; \
		echo -e "\a"; \
		echo "Create the signed certificate"; \
		openssl x509 -req -in ${SSL_DIR}/$$domain.csr -CA ${SSL_DIR}/${myCA.pem} -CAkey ${SSL_DIR}/${myCA.key} \
		-CAcreateserial -out ${CERTS_DIR}/$$domain.crt -days 3650 \
		-sha256 -extfile ${SSL_DIR}/$$domain.ext; \
	fi;
	@echo "Everything good! Don't forget to add the trusted certificate to your system" ;\

.PHONY: cert_add
cert_add:ssl-dir CA-private-key CA-root-cert CA-signed-certs_create 		## Add a new local self signed certificate for HTTPS connection

.PHONY: cert_check
cert_check:		## Check your self signed certificate
	@read -p "Enter domain name you want to check :" domain; \
	if [ ! "$$domain" ]; then \
		echo "Please set your domain name"; \
		exit 0; \
	else \
		openssl verify -verbose -CAfile ${SSL_DIR}/${myCA.pem} ${CERTS_DIR}/$$domain.crt; \
	fi;

.PHONY: keychain_add
keychain_add:		## Add a certificate in Keychain (Mac users)
	@read -p "Enter domain name you want to add in Keychain (e.g. mydomain.com) [root password is requested]:" domain; \
	if [ ! "$$domain" ]; then \
		echo "Please set your domain name"; \
		exit 0; \
	else \
		sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain ${CERTS_DIR}/$$domain.crt; \
	fi;
	@echo "Your new certificate has been added in Keychain"

.PHONY: help
help:		## Show this help
	@echo -e "$$(grep -hE '^\S+:.*##' $(MAKEFILE_LIST) | sed -e 's/:.*##\s*/:/' -e 's/^\(.\+\):\(.*\)/\\x1b[36m\1\\x1b[m:\2/' | column -c2 -t -s :)"
