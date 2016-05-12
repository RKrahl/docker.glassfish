#!/bin/bash

certsdir=/etc/glassfish/certs
domainname=domain1
domaindir=/opt/glassfish4/glassfish/domains/$domainname


glassfish_init() {
    adminpw="$(pwgen -s 32 1)"
    pwfile=$(mktemp)
    echo "AS_ADMIN_PASSWORD=${adminpw}" > $pwfile
    echo "ADMIN PASSWORD = ${adminpw}"
    asadmin --passwordfile $pwfile --user admin \
	create-domain --savelogin $domainname
    rm -f $pwfile
    asadmin start-domain $domainname
    asadmin enable-secure-admin
    asadmin stop-domain $domainname
    if [ ! -z "$GF_DOMAIN_LIBS" ]; then
	for f in ${GF_DOMAIN_LIBS}; do
	    test -f $f && ln -s $f $domaindir/lib
	done
    fi
    if [ -d $certsdir ]; then
	# The certs directory is present, e.g. it has been added by a
	# bind mount.  It contains the SSL certificate we should use.
	# Add the certificate to Glassfish's keystore, overwriting the
	# self-signed certificate that Glassfish created during
	# create-domain.
	tmpfile=`mktemp`
	openssl pkcs12 -export -chain \
	    -in $certsdir/cert.pem -inkey $certsdir/key.pem \
	    -CAfile $certsdir/cacert.pem \
	    -out $tmpfile -name s1as -passout pass:changeit
	keytool -importkeystore \
	    -srckeystore $tmpfile -srcstoretype pkcs12 \
	    -srcstorepass changeit \
	    -destkeystore $domaindir/config/keystore.jks -deststoretype jks \
	    -deststorepass changeit \
	    -noprompt
	rm -f $tmpfile
    fi
    asadmin start-domain $domainname
    asadmin set server.http-service.access-log.format="common"
    asadmin set server.http-service.access-logging-enabled=true
    asadmin set server.thread-pools.thread-pool.http-thread-pool.max-thread-pool-size=128
    asadmin set configs.config.server-config.cdi-service.enable-implicit-cdi=false
    asadmin set server.ejb-container.property.disable-nonportable-jndi-names="true"
    asadmin delete-ssl --type http-listener http-listener-2
    asadmin delete-network-listener http-listener-2
    asadmin create-network-listener --listenerport 8181 --protocol http-listener-2 http-listener-2
    asadmin create-ssl --type http-listener --certname s1as --ssl3enabled=false --ssl3tlsciphers +TLS_RSA_WITH_AES_256_CBC_SHA,+TLS_RSA_WITH_AES_128_CBC_SHA http-listener-2
    asadmin set configs.config.server-config.network-config.protocols.protocol.http-listener-2.http.request-timeout-seconds=-1

    for f in /etc/glassfish.d/*; do
	case "$f" in
	    *.sh)    echo "running $f"; . "$f" ;;
	    *)       echo "ignoring $f" ;;
	esac
    done
}

if [[ ! -d $domaindir ]]; then
    glassfish_init
else
    asadmin start-domain
fi

echo "GlassFish is running."