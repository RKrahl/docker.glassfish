#!/bin/bash

certsdir=/etc/glassfish/certs
domainname=domain1

DOMAINDIR=$GLASSFISH_HOME/glassfish/domains/$domainname
export DOMAINDIR


glassfish_init() {
    adminpw="$(pwgen -s 32 1)"
    pwfile=$(mktemp)
    echo "AS_ADMIN_PASSWORD=${adminpw}" > $pwfile
    asadmin --passwordfile $pwfile --user admin \
	create-domain --savelogin $domainname
    rm -f $pwfile
    asadmin start-domain $domainname
    asadmin enable-secure-admin
    asadmin stop-domain $domainname
    if [ ! -z "$GF_DOMAIN_LIBS" ]; then
	for f in ${GF_DOMAIN_LIBS}; do
	    test -f $f && ln -s $f $DOMAINDIR/lib
	done
    fi
    if [ -d $certsdir ]; then
	# The certs directory is present, e.g. it has been added by a
	# bind mount.  It contains the SSL certificate we should use.
	# Add the certificate to Payara's keystore, overwriting the
	# self-signed certificate that Payara created during
	# create-domain.
	tmpfile=`mktemp`
	# Remove the self-signed certificate from Payara's cacerts.p12.
	keytool -delete -alias s1as \
		-keystore $DOMAINDIR/config/cacerts.p12 -storetype pkcs12 \
		-storepass changeit \
		-noprompt
	# Check whether the root ca is already in cacerts.p12 and add
	# it if needed.
	rootfp=`openssl x509 -in $certsdir/rootcert.pem \
                    -noout -sha256 -fingerprint | cut -d '=' -f 2 -s`
	if ! (keytool -list -keystore $DOMAINDIR/config/cacerts.p12 \
	          -storetype pkcs12 -storepass changeit \
	          | grep -q $rootfp); then
	    echo "Import root cert to cacerts.p12"
	    # Choose a random alias for the new ca entry that is very
	    # unlikely to collide with an already existing one.
	    alias=`pwgen 32 1`
	    openssl x509 -in $certsdir/rootcert.pem -outform der -out $tmpfile
	    keytool -import -file $tmpfile -alias $alias \
		-keystore $DOMAINDIR/config/cacerts.p12 -storetype pkcs12 \
		-storepass changeit \
		-noprompt
	fi
	echo "Import cert.pem to keystore.p12"
	if [ -f $certsdir/certchain.pem ]; then
	    openssl pkcs12 -export -chain \
		-in $certsdir/cert.pem -inkey $certsdir/key.pem \
		-CAfile $certsdir/certchain.pem \
		-out $tmpfile -name s1as -passout pass:changeit
	else
	    openssl pkcs12 -export \
		-in $certsdir/cert.pem -inkey $certsdir/key.pem \
		-out $tmpfile -name s1as -passout pass:changeit
	fi
	keytool -importkeystore \
	    -srckeystore $tmpfile -srcstoretype pkcs12 \
	    -srcstorepass changeit \
	    -destkeystore $DOMAINDIR/config/keystore.p12 -deststoretype pkcs12 \
	    -deststorepass changeit \
	    -noprompt
	rm -f $tmpfile
    fi
    asadmin start-domain $domainname
    asadmin set server.http-service.access-log.format="common"
    asadmin set server.http-service.access-logging-enabled=true
    asadmin set server.thread-pools.thread-pool.http-thread-pool.max-thread-pool-size=128
    asadmin set server.ejb-container.property.disable-nonportable-jndi-names="true"
    asadmin set configs.config.server-config.network-config.protocols.protocol.http-listener-2.http.request-timeout-seconds=-1
    asadmin create-network-listener --protocol http-listener-1 --listenerport 8009 --jkenabled true jk-connector

    mkdir $DOMAINDIR/data

    for f in /etc/glassfish/post-install.d/*; do
	case "$f" in
	    *.sh)    echo "running $f"; . "$f" ;;
	    *)       echo "ignoring $f" ;;
	esac
    done
}


if [[ ! -e $GLASSFISH_HOME/.gfclient ]]; then
    mkdir -p $GLASSFISH_HOME/glassfish/domains/.gfclient
    ln -s glassfish/domains/.gfclient $GLASSFISH_HOME
fi

if [[ ! -d $DOMAINDIR ]]; then
    glassfish_init
else
    asadmin start-domain
fi

for f in /etc/glassfish/post-startup.d/*; do
    case "$f" in
	*.sh)    echo "running $f"; . "$f" ;;
	*)       echo "ignoring $f" ;;
    esac
done

echo "GlassFish is running."
