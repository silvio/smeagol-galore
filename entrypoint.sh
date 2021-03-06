#!/usr/bin/env bash

# Exported so they can be read from tomcat process
export ADMIN_GROUP=${ADMIN_GROUP:-admin}
export FQDN=${FQDN:-localhost:8443}
export USER_HOME=/home/tomcat

DEBUG=${DEBUG:-false}
EXTRA_JVM_ARGUMENTS=${EXTRA_JVM_ARGUMENTS:-}
DEFAULT_FQDN="localhost\:8443"


set -o errexit -o nounset -o pipefail

main() {

    createSelfSignedCert

    writeFQDN

    initWiki

    startTomcat
}

createSelfSignedCert() {

    keystore=/usr/local/tomcat/conf/keystore.jks
    trustStore=/etc/ssl/certs/java/cacerts
    cert=/tmp/server.cer
    host=$(echo "${FQDN}" | sed -e 's/:/\n/g' | head -1)

    if [ ! -f ${keystore} ]; then

        echo "No Keystore mounted, creating and trusting self-signed certificate"


        # In order to authenticate via scm-cas-plugin, we need to provide a subjectAltName otherwise we'll encounter
        # ClientTransportException: HTTP transport error: javax.net.ssl.SSLHandshakeException: java.security.cert.CertificateException: No subject alternative names present
        # See https://stackoverflow.com/a/84441845976863/

        keytool -genkey -noprompt \
         -ext san=ip:127.0.0.1 -ext san=dns:${host} \
         -alias ${host} \
         -keyalg RSA -keypass changeit -storepass changeit -keystore ${keystore} \
         -dname "CN=${host}, OU=Unknown, O=Unknown, L=Unknown, S=Unknown, C=Unknown"

        keytool -export -alias ${host} -storepass changeit -file ${cert}  -keystore ${keystore}

        keytool -import -noprompt -v -trustcacerts -alias ${host} -file ${cert} -keystore ${trustStore} -keypass changeit -storepass changeit
    fi

    chmod 444 ${trustStore}
}

writeFQDN() {

    files=( \
        # Note that in SCMM the FQDN is set up using the groovy scripts
        "/usr/local/tomcat/application.yml" \
        "/etc/cas/cas.properties" \
        "/usr/local/tomcat/webapps/cas/WEB-INF/deployerConfigContext.xml" \
        "/usr/local/tomcat/webapps/cas/WEB-INF/spring-configuration/uniqueIdGenerators.xml" )


    for i in "${files[@]}"
    do
        echo "Updating FQDN in ${i} (FQDN=${FQDN})"
        sed -i "s/${DEFAULT_FQDN}/${FQDN}/" ${i}
    done
}

initWiki() {

    if [ -z "$(ls -A ${USER_HOME}/.scm)" ]; then
        echo "Creating default wiki"
        cp -r /opt/scm-server/defaults/* ${USER_HOME}/.scm
    fi
}

startTomcat() {

    DEBUG_PARAM=""
    if [ "${DEBUG}" == "true" ]
    then
        export JPDA_OPTS="-agentlib:jdwp=transport=dt_socket,address=8000,server=y,suspend=n"
        DEBUG_PARAM=jpda
    fi

    export CATALINA_OPTS="${EXTRA_JVM_ARGUMENTS} -Dsonia.scm.init.script.d=/opt/scm-server/init.script.d"
    catalina.sh ${DEBUG_PARAM} run

    # TODO use "startup.sh -security"?
    #exec su-exec tomcat  startup.sh -security
    # Never exit
    #while true; do sleep 10000; done
}

main "$@"
