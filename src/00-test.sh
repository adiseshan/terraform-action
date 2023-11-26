#!/bin/bash

export INPUT_RUN_INIT=false
export INPUT_INIT_ADDITIONAL_ARGUMENTS="-upgrade=true -reconfigure -compact-warnings -backend-config=../tf-vars/env-name/backend.tf"
export INPUT_COMMAND=plan
export INPUT_ADDITIONAL_ARGUMENTS="--var-file=../tf-vars/env-name/params.tfvars"
export INPUT_GLOBAL_ARGUMENTS="-chdir=./gha-test"
export INPUT_PATH="./"
export INPUT_LOG_LEVEL=info
export GITHUB_TOKEN="xx"
export INPUT_GITHUB_BASE_URL="https://api.github.com/api/v3"
export INPUT_GITHUB_HOSTNAME=github.com
export INPUT_OWNER="adiseshan"
export INPUT_REPO="gha-test-1"
export INPUT_PR_NUMBER="29"
export INPUT_TARGET="test"
