N_FILE=$1
OUT_FILE=$2

openssl smime \
-sign \
-signer /usr/local/pf/raddb/certs/eapca.pem \
-inkey /usr/local/pf/raddb/certs/eapca.key \ 
-nodetach \
-outform der \
-in $IN_FILE \
-out $OUT_FILE 
