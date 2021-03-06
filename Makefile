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

DOMAIN ?= $(shell bash -c 'read -p "Enter domain name you want to add (e.g. mydomain.com) :" domain; echo $$domain')
IP_ADDRESS ?= $(shell bash -c 'read -p "Enter ip address (leave blank for default 127.0.0.1) :" ipaddress; echo $$ipaddress')
SITE_ID ?= $(shell bash -c 'read -p "Enter site id (leave blank if not requested in configuration file):" siteid; echo $$siteid')
TEMPLATE_LIST := $(shell bash -c 'ls templates/_* | xargs -n 1 basename |  tr "\n" ","')
TAMPLATE_NAME ?= $(shell bash -c 'read -p "Type one of the available configuration files [${TEMPLATE_LIST}]:" tamplate_name; echo $$tamplate_name')

.PHONY: domain
domain:	## Add a new domain in NGINX
	@domain=$(DOMAIN); \
	ipaddress=$(IP_ADDRESS); \
	siteid=$(SITE_ID); \
	template_name=$(TAMPLATE_NAME); \
	if [ ! "$$domain" ]; then \
		echo "Please set your domain name"; \
		exit 0; \
	fi; \
	if [ ! "$$ipaddress" ]; then \
		ipaddress='127.0.0.1'; \
	fi; \
	if [ ! "$$siteid" ]; then \
		echo "Site ID empty"; \
	fi; \
	if [ ! "$$template_name" ]; then \
		echo 'Please type one of available configuration template:'; \
		ls templates/_* | xargs -n 1 basename; \
		exit 0; \
	fi; \
	sed -e "s/DOMAIN_NAME/$$domain/g" -e "s/IP_ADDRESS/$$ipaddress/g" -e "s/SITE_ID/$$siteid/g" templates/$$template_name > sites-available/$$domain.conf; \
	set -x; \
			cd sites-enabled; \
			ln -fs ../sites-available/$$domain.conf $$domain.conf; \
	echo "Everything good! New domain name $$domain has been added. Don't forget to add a new certicate with same name $$domain" ;\

.PHONY: ssl-dir
ssl-dir:
	@if [[ ! -d ${SSL_DIR} ]]; then \
		mkdir ${SSL_DIR}; \
		echo "Local folder ${SSL_DIR} has been created"; \
	fi;

.PHONY: CA-private-key
CA-private-key:
	@if [[ ! -f ${SSL_DIR}/${myCA.key} ]]; then \
		openssl genrsa -des3 -out /${SSL_DIR}/${myCA.key} 2048; \
		echo "Certificate Authority private key has been generated"; \
	fi;

.PHONY: CA-root-cert
CA-root-cert:
	@if [[ ! -f ${SSL_DIR}/${myCA.pem} ]]; then \
		echo "Please fill at least 'Country Name' and 'State or Province Name' questions"; \
		openssl req -x509 -new -nodes -key ${SSL_DIR}/${myCA.key} -sha256 -days 825 -out ${SSL_DIR}/${myCA.pem}; \
		echo "Certificate Authority root certificate has been generated"; \
	fi;

.PHONY: CA-signed-certs_create
CA-signed-certs_create:
	@domain=$(DOMAIN); \
	ipaddress=$(IP_ADDRESS); \
	if [ ! "$$domain" ]; then \
		echo "Please set your domain name"; \
		exit 0; \
	fi; \
	if [ ! "$$ipaddress" ]; then \
		ipaddress='127.0.0.1'; \
	fi; \
	echo "Generate a private key"; \
	openssl genrsa -out ${CERTS_DIR}/$$domain.key 2048; \
	echo "Create a certificate-signing request"; \
	echo -e "\a"; \
	echo "WARNING! For Mac users: make sure to set the 'Common Name' to the same as domain name setted (in your case: $$domain) when it's asking for setup"; \
	echo -e "\a"; \
	openssl req -new -key ${CERTS_DIR}/$$domain.key -out ${SSL_DIR}/$$domain.csr; \
	echo "Create a config file for the extensions"; \
	sed -e "s/DOMAIN_NAME/$$domain/g" -e "s/IP_ADDRESS/$$ipaddress/g" templates/certificate-extension.conf > ${SSL_DIR}/$$domain.ext; \
	echo -e "\a"; \
	echo "WARNING! For Not Mac users you can comment line 'extendedKeyUsage=serverAuth,clientAuth' in newly created file ${SSL_DIR}/$$domain.ext"; \
	echo -e "\a"; \
	echo "Create the signed certificate"; \
	openssl x509 -req -in ${SSL_DIR}/$$domain.csr -CA ${SSL_DIR}/${myCA.pem} -CAkey ${SSL_DIR}/${myCA.key} \
	-CAcreateserial -out ${CERTS_DIR}/$$domain.crt -days 825 \
	-sha256 -extfile ${SSL_DIR}/$$domain.ext; \
	echo "Everything good! Don't forget to add the trusted certificate to your system" ;\

.PHONY: cert
cert:ssl-dir CA-private-key CA-root-cert CA-signed-certs_create 		## Add a new local self signed certificate for HTTPS connection

.PHONY: cert-check
cert-check:		## Check your self signed certificate
	@domain=$(DOMAIN); \
	if [ ! "$$domain" ]; then \
		echo "Please set your domain name"; \
		exit 0; \
	fi; \
	openssl verify -verbose -CAfile ${SSL_DIR}/${myCA.pem} ${CERTS_DIR}/$$domain.crt; \

.PHONY: keychain-add
keychain-add:		## Add a certificate in Keychain (Mac users)
	@domain=$(DOMAIN); \
	if [ ! "$$domain" ]; then \
		echo "Please set your domain name (root password required)"; \
		exit 0; \
	fi; \
	sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain ${CERTS_DIR}/$$domain.crt; \
	echo "Your new certificate has been added in Keychain"

.PHONY: stop
stop:		## Stop all services
	docker-compose stop

.PHONY: start
start:		## Start all services
	docker-compose start

.PHONY: restart
restart:		## Restart all services
	docker-compose restart

.PHONY: help
help:		## Show this help
	@echo -e "$$(grep -hE '^\S+:.*##' $(MAKEFILE_LIST) | sed -e 's/:.*##\s*/:/' -e 's/^\(.\+\):\(.*\)/\\x1b[36m\1\\x1b[m:\2/' | column -c2 -t -s :)"
