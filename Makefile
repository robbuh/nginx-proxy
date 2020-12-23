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

.PHONY: CA_private_key
CA_private_key:
	@if [[ ! -f ${SSL_DIR}/${myCA.key} ]]; then \
		openssl genrsa -des3 -out /${SSL_DIR}/${myCA.key} 2048; \
	fi;

.PHONY: CA_root_cert
CA_root_cert:
	@if [[ ! -f ${SSL_DIR}/${myCA.pem} ]]; then \
		openssl req -x509 -new -nodes -key ${SSL_DIR}/${myCA.key} -sha256 -days 825 -out ${SSL_DIR}/${myCA.pem}; \
	fi;

.PHONY: create_CA_signed_certs
.ONESHELL:
create_CA_signed_certs:
	@read -p "Enter your domain name (e.g. mydomain.com) :" domain; \
	if [ ! "$$domain" ]; then \
		echo "Please set your domain name"; \
		exit 0; \
	else \
		openssl genrsa -out ${CERTS_DIR}/$$domain.key 2048; \
		echo -e "\a"; \
		echo "ALERT! For Mac users: make sure to set the 'Common Name' to the same as domain name setted (in your case: $$domain) when it's asking for setup"; \
		echo -e "\a"; \
		openssl req -new -key ${CERTS_DIR}/$$domain.key -out ${SSL_DIR}/$$domain.csr; \
		cat <<- EOF > ${SSL_DIR}/$$domain.ext
			Test
		EOF; \
	fi;




.PHONY: help
help:		## Show this help
	@echo -e "$$(grep -hE '^\S+:.*##' $(MAKEFILE_LIST) | sed -e 's/:.*##\s*/:/' -e 's/^\(.\+\):\(.*\)/\\x1b[36m\1\\x1b[m:\2/' | column -c2 -t -s :)"
