#!/bin/bash

export INPUT_RUN_INIT=false
export INPUT_INIT_ADDITIONAL_ARGUMENTS="-upgrade=true -reconfigure -compact-warnings -backend-config=../tf-vars/ap-northeast-1/backend.tf"
export INPUT_COMMAND=plan
export INPUT_ADDITIONAL_ARGUMENTS="--var-file=../tf-vars/ap-northeast-1/params.tfvars"
export INPUT_GLOBAL_ARGUMENTS="-chdir=./tf-awscommons"
export INPUT_PATH="./"
export INPUT_LOG_LEVEL=info
export GITHUB_TOKEN="xx"
export INPUT_GITHUB_BASE_URL="https://api.github.com/api/v3"
export INPUT_GITHUB_HOSTNAME=github.com
export INPUT_OWNER="adiseshan"
export INPUT_REPO="aws-commons"
export INPUT_PR_NUMBER="1"
export INPUT_TARGET="ap-northeast-1"
