# terraform-action

This action is a wrapper for terraform. Enables gitops based management for terraform projects.

## Pre-requisites

- actions/checkout should be invoked so that the repository is cloned and available in the workspace.
- A runner with various tools pre-installed is required. 
  - jq, yq, gh, zip, unzip, tar, terraform, tfcmt
  - Other tools based on the terraform provisioner usages. 
  - Recommended to use runner-image [adiseshan/terraform-cicd:v1.0.0](https://hub.docker.com/repository/docker/adiseshan/terraform-cicd/general)

## What's inside

- Works with any version in the underlining runner image.
  - Sample image [adiseshan/terraform-cicd:v1.0.0](https://hub.docker.com/repository/docker/adiseshan/terraform-cicd/general)
- `actions/checkout` should be done so that the source is available for the terraform command.
- Works with 2 modes.
  - plan
  - apply
- The flow is as follows
  - checkout the source code.
  - login into appropriate cloud environment. for eg., using `aws-actions-configure-aws-credentials`
  - Based on the input `INPUT_SECRETS_JSON` the secrets are exported into `env`
  - Extract/Identify the PR number. 
    - If the action is run with `plan` mode on a `pull_request` event then pr number can be passed as input.
    - If the action is run with `apply` mode on a `push` event then pr number will be identified automatically based on the git sha.
    - Hence either `INPUT_PR_NUMBER` or `INPUT_GITHUB_SHA` is mandatory.
  - `terraform init` is executed. Refer the input list to send appropriate parameters. 
  - `terraform plan/apply` is executed.
  - Results are posted as PR comments. Highlighted with create/update/destroy tags etc.,

# What's new

Please refer to the [release page](https://github.com/adiseshan/terraform-action/releases/latest) for the latest release notes.

# Usage

<!-- start usage -->
```yaml
# Pre-requisite to release a new version.
- uses: actions/checkout@v3

- name: Extract PR number
  id: get-pr-info
  uses: adiseshan/get-pr-info-action@v1
  with:
    # Optional. Whether to run terraform init
    # Default: true
    INPUT_RUN_INIT: true
    # Arguments to pass for terraform init
    INPUT_INIT_ADDITIONAL_ARGUMENTS: ''
    # Optional. terraform plan or apply
    # Default: plan
    INPUT_COMMAND: plan
    # terraform additional arguments
    # More info at https://developer.hashicorp.com/terraform/cli/commands
    INPUT_ADDITIONAL_ARGUMENTS: ''
    # terraform global arguments
    # More info at https://developer.hashicorp.com/terraform/cli/commands
    INPUT_GLOBAL_ARGUMENTS: ''
    # Optional. the relative location of terraform files
    # Default '.'
    INPUT_PATH: ''
    # Optional. Log level
    # Default: info
    INPUT_LOG_LEVEL: info
    # The action secrets as json to extract TF_VARS if any.
    INPUT_SECRETS_JSON: ''
    # Optional. The prefix with which TF_VARS should be extracted.
    # Default: TF_VARS
    INPUT_SECRETS_FILTER_PREFIX: TF_VARS
    # Optional. To be used for ghe.
    # Default: github.com
    INPUT_TARGET:
    # "optional. suffix to add to title"
    INPUT_GITHUB_HOSTNAME: github.com
    # A token with `repo` priviledge to post comments in the PR.
    GITHUB_TOKEN: ''
    # Repo owner
    INPUT_GITHUB_REPOSITORY_OWNER: ''
    # Repo name
    INPUT_GITHUB_REPOSITORY_NAME: ''
    # Conditional. Either of INPUT_PR_NUMBER or INPUT_GITHUB_SHA should be provided.
    # If provided, the results will be posted to this PR.
    INPUT_PR_NUMBER: ''
    # Conditional. Either of INPUT_PR_NUMBER or INPUT_GITHUB_SHA should be provided.
    # If INPUT_PR_NUMBER is not provided, then PR will be identified based on the git sha.
    INPUT_GITHUB_SHA: ''
```
<!-- end usage -->

# Scenarios 

- [Terraform plan on PR](#terraform-plan-on-pr)
- [Terraform apply on merge/push](#terraform-apply-on-push)

## Terraform plan on pr

```yaml
name: workflow-for-pr
permissions:
  id-token: write
  contents: read
on:
  pull_request:
    branches:
    - prod

env:
  DOCKER_USER: ${{ secrets.DOCKER_USER }}
  DOCKER_TOKEN: ${{ secrets.DOCKER_TOKEN }}
  GITHUB_HOSTNAME: github.com
  GITHUB_TOKEN: ${{ secrets.BOT_GITHUB_TOKEN }}
  APP_ENV: ${{ github.base_ref }}

jobs:
        
  pr-workflow:
    runs-on: ubuntu-latest
    container: 
      image: adiseshan/terraform-cicd:v1.0.0
      credentials:
        username: ${{ env.DOCKER_USER }}
        password: ${{ env.DOCKER_TOKEN }}
    steps:
    # checkout starts
      - uses: actions/checkout@v3
        with:
          fetch-depth: 1
    # checkout ends

      # # aws login starts
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: xxxxxx
          role-session-name: githubsession
          aws-region: yyyyy
      # # aws login ends

      - name: Terraform plan
        id: terraform-test
        uses: adiseshan/terraform-action@v1
        with:
          INPUT_TARGET: ${{ env.APP_ENV }}
          INPUT_PATH: ./infra-as-code
          INPUT_INIT_ADDITIONAL_ARGUMENTS: -upgrade=true -reconfigure -compact-warnings -backend-config=../tf-vars/${{ env.APP_ENV }}/backend.tf
          INPUT_COMMAND: plan
          INPUT_ADDITIONAL_ARGUMENTS: --var-file=../tf-vars/${{ env.APP_ENV }}/params.tfvars
          INPUT_GLOBAL_ARGUMENTS: -chdir=./gha-test
          INPUT_SECRETS_JSON: $${{ toJSON(secrets) }}
          INPUT_GITHUB_HOSTNAME: ${{ env.GITHUB_HOSTNAME }}
          GITHUB_TOKEN: ${{ env.GITHUB_TOKEN }}
          INPUT_GITHUB_REPOSITORY_OWNER: ${{ github.repository_owner }}
          INPUT_GITHUB_REPOSITORY_NAME: ${{ github.event.repository.name }}
          INPUT_PR_NUMBER: ${{ github.event.number }}
```

## Terraform apply on push

```yaml
name: workflow-for-merge
permissions:
  id-token: write
  contents: read
on:
  push:
    branches:
    - prod

  workflow_dispatch:

env:
  GITHUB_HOSTNAME: github.com
  GITHUB_TOKEN: ${{ secrets.BOT_GITHUB_TOKEN }}
  DOCKER_USER: ${{ secrets.DOCKER_USER }}
  DOCKER_TOKEN: ${{ secrets.DOCKER_TOKEN }}
  APP_ENV: ${{ github.ref_name }}

jobs:
        
  general-test1:
    runs-on: ubuntu-latest
    container: 
      image: adiseshan/terraform-cicd:v1.0.0
      credentials:
        username: ${{ env.DOCKER_USER }}
        password: ${{ env.DOCKER_TOKEN }}
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 1

      # # aws login starts
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: xxxxxx
          role-session-name: githubsession
          aws-region: yyyyy
      # # aws login ends

      - name: Terraform apply
        id: terraform-apply
        uses: adiseshan/terraform-action@v1
        with:
          INPUT_TARGET: ${{ env.APP_ENV }}
          INPUT_PATH: ./infra-as-code
          INPUT_INIT_ADDITIONAL_ARGUMENTS: -upgrade=true -reconfigure -compact-warnings -backend-config=../tf-vars/${{ env.APP_ENV }}/backend.tf
          INPUT_COMMAND: apply
          INPUT_ADDITIONAL_ARGUMENTS: --var-file=../tf-vars/${{ env.APP_ENV }}/params.tfvars
          INPUT_GLOBAL_ARGUMENTS: -chdir=./gha-test
          INPUT_SECRETS_JSON: $${{ toJSON(secrets) }}
          INPUT_GITHUB_HOSTNAME: ${{ env.GITHUB_HOSTNAME }}
          GITHUB_TOKEN: ${{ env.GITHUB_TOKEN }}
          INPUT_GITHUB_REPOSITORY_OWNER: ${{ github.repository_owner }}
          INPUT_GITHUB_REPOSITORY_NAME: ${{ github.event.repository.name }}
          INPUT_GITHUB_SHA: ${{ github.sha }}

```
