#!/bin/bash
# Author: Adiseshan K
# Pre requisites
# FILTER_PREFIX 
# INPUT_JSON 

set -o pipefail

validate() {
    echo "[INFO] validate"
    
    if ! jq --version; then
        echo "[ERR] yq command not found"
        exit 1
    fi
}

main() {
    validate
    echo "[INFO] filtering the items based on prefix: ${FILTER_PREFIX}"
    for key_value in $(jq --arg FILTER_PREFIX "${FILTER_PREFIX}" '. | with_entries(select (.key|startswith($FILTER_PREFIX)))' <<< "${INPUT_JSON:1}" | jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]"); do
        echo "${key_value}" >> "$GITHUB_ENV"
    done
}

main "$@"
