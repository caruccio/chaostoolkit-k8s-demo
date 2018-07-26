#!/bin/bash
#
# References:
#  https://stackoverflow.com/questions/23523456/how-to-give-a-multiline-certificate-name-cn-for-a-certificate-generated-using
#  https://stackoverflow.com/questions/4024393/difference-between-self-signed-ca-and-self-signed-certificate
#  https://web.archive.org/web/20160403100211/https://metabrot.rocho.org/jan/selfsign.html
#  https://jamielinux.com/docs/openssl-certificate-authority/appendix/root-configuration-file.html
#  man x509v3_config


mkdir -p certs
set -eu

CN=$1
DAYS=$2
OUT=${3:-$CN}

set -x

if [ ! -e certs/ca.crt ]; then
    echo Generating self signing CA
    echo
    openssl genrsa -out certs/ca.key 2048
    openssl req -nodes -new -x509 -days 3650 -key certs/ca.key -out certs/ca.crt \
        -subj "/C=BR/ST=Sao Paulo/L=Sao Paulo/O=Getup Cloud Inc./OU=IT/CN=getupcloud.com" \
        -extensions v3_ca -config ca.cnf
fi
> certs/index.txt
echo 1000 > certs/serial

echo "Generating self signed certificate for $CN ($DAYS days)"
echo
openssl genrsa -out certs/$OUT.key 2048

openssl req -new -key certs/$OUT.key \
    -subj "/C=BR/ST=Sao Paulo/L=Sao Paulo/O=Getup Cloud Inc./OU=IT/CN=$CN" -out certs/$OUT.csr

#openssl x509 -req -days $DAYS -in certs/$OUT.csr \
#    -extfile ca.cnf -extensions CA -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial -out certs/$OUT.crt

openssl ca -config ca.cnf \
      -extensions server_cert -days $DAYS -notext \
      -in certs/$OUT.csr\
      -out certs/$OUT.crt

cat certs/$OUT.crt certs/ca.crt > certs/ca-bundle-$OUT.crt
ls -l certs/$OUT.*
