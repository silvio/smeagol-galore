#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

main() {

    validateScmRestApiUsesCas

    validateSmeagolUsesCas
}

validateScmRestApiUsesCas() {

    echo "$(date +"%Y-%m-%d %H:%M:%S") Trying to validate SCMM REST API uses CAS"
    
    # Startup might take 200s and more because of the installed plugins, SCMM restart and CAS service reload on first start
    TIMEOUT=500 
    for i in $(seq 1 ${TIMEOUT}) 
    do
        result=$(curl -su admin:admin --insecure https://localhost:8443/scm/api/rest/users.json 2>&1)

        # Validate our admin user is returned
        if echo ${result} | grep scm@adm.in; then
            echo "$(date +"%Y-%m-%d %H:%M:%S") validateScmRestApiUsesCas successful"
            break
        fi

        if [ "$i" = "${TIMEOUT}" ]; then 
            echo "$(date +"%Y-%m-%d %H:%M:%S") validateScmRestApiUsesCas fail after ${TIMEOUT} tries: ${result}"
            return 1
         fi

         sleep 1
    done
}

validateSmeagolUsesCas() {
    # TODO can we do a smeagol login on CLI?
    echo "$(date +"%Y-%m-%d %H:%M:%S") validateSmeagolUsesCas not implemented, yet"
}

main "$@"
