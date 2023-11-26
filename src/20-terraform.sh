#!/bin/bash
# Pre requisites
# Author: Adiseshan K

set -o pipefail

declare -r CONFIG_PATH=".tfcmt.yaml"

validate() {
    echo "[INFO] validate"
    
    if ! jq --version; then
        echo "[ERR] yq command not found"
        exit 1
    fi
    if ! gh version; then
        echo "[ERR] gh command not found"
        exit 1
    fi
}



setup() {
    git config --global --add safe.directory "*"
    echo "${GITHUB_TOKEN}" | gh auth login --hostname "${INPUT_GITHUB_HOSTNAME}" --git-protocol https --with-token
    git_status_check_cmd="gh auth status --hostname ${INPUT_GITHUB_HOSTNAME}"
	if ! ${git_status_check_cmd}; then
        echo "git status check failed for hostname ${INPUT_GITHUB_HOSTNAME}. "
        exit 1
    fi

}

hide_old_plans() {
    echo "trying to hide old plan related comments in pr ${INPUT_PR_NUMBER}"
    if [[ -n "${INPUT_PR_NUMBER}" ]]; then
        for subject_id in $(gh pr view "${INPUT_PR_NUMBER}" --json=comments |jq -c '.comments[] | select(.body | test("github-comment:")?) | select(.body | test("Command\":\"plan\"")? ) | select (.isMinimized == false) | .id'); do
            echo "identified old plan ${subject_id}"
            # shellcheck disable=SC2016
            gh api graphql -f subjectid="${subject_id}" -F query='mutation ($subjectid: ID!) { minimizeComment( input: { subjectId: $subjectid  classifier: OUTDATED } ) { minimizedComment { isMinimized } } } '
        done
    fi
}

main() {
    validate
    setup

    local path="${INPUT_PATH:-.}"
    local command="${INPUT_COMMAND:-init}"

    case "${command}" in
        "plan")
            hide_old_plans
            ;;
        "apply")
            # skip
            ;;
        "destroy")
            # skip
            ;;
        *)
            echo "[ERROR] Command ${command} not supported. Only \`plan\` or \`apply\` are allowed" >&2
            return 1
            ;;
    esac

    local -a tfcmt_args=(
        -owner "${INPUT_OWNER}"
        -repo "${INPUT_REPO}"
        --log-level "${INPUT_LOG_LEVEL:-info}"
    )

    if [[ -n "${GITHUB_CHECK_RUN_HTML_URL}" ]]; then
        tfcmt_args+=(
            -build-url "${GITHUB_CHECK_RUN_HTML_URL}"
        )
    fi
    if [[ -n "${INPUT_TARGET}" ]]; then
        tfcmt_args+=(
            -var target:"${INPUT_TARGET}"
        )
    fi

    # shellcheck disable=SC2206
    local -a tf_args=(
        -no-color
        ${INPUT_ADDITIONAL_ARGUMENTS}
    )

    pushd "${path}" > /dev/null || exit

    echo "[INFO] Setup ${CONFIG_PATH} in $(pwd)"
    touch "${CONFIG_PATH}"

    # TODO make it optional
    # yq -i ".ghe_base_url = \"${INPUT_GITHUB_BASE_URL}\"" "${CONFIG_PATH}"

    if [[ "${command}" == "apply" ]]; then
        tf_args+=(
            -auto-approve
        )
    fi
    if [[ "${command}" == "destroy" ]]; then
        tf_args+=(
            -auto-approve
        )
    fi

    if [[ "${INPUT_RUN_INIT:-true}" == "true" ]]; then
        echo "[INFO] Running terraform init in $(pwd)"
        tf_init_cmd="terraform ${INPUT_GLOBAL_ARGUMENTS} init ${INPUT_INIT_ADDITIONAL_ARGUMENTS}"
        echo "[INFO] ${tf_init_cmd}"
        if ! ${tf_init_cmd}; then
            # TODO. post the failures as PR comments
            echo "terraform init failed "
            exit 1
        fi
    fi

    if [[ -n "${INPUT_PR_NUMBER}" ]]; then
        tfcmt_args+=(-pr "${INPUT_PR_NUMBER}" )
    fi

    echo "[INFO] Running terraform ${command} in $(pwd) with ${tf_args[*]} arguments"

    # shellcheck disable=SC2068
    if [[ -n "${GITHUB_TOKEN}" ]] && [[ "${command}" != "destroy" ]]; then
        # NOTE(Adi): 
        # Pass the envs with INPUT_ instead of directly configuring GITHUB_xxx
        # not to conflict with other usages (e.g. GitHub Terraform Provider)
        echo tfcmt ${tfcmt_args[@]} "${command}" -- terraform "${INPUT_GLOBAL_ARGUMENTS}" "${command}" ${tf_args[@]}
        if ! tfcmt ${tfcmt_args[@]} "${command}" -- terraform "${INPUT_GLOBAL_ARGUMENTS}" "${command}" ${tf_args[@]}; then
            echo terraform "${command}" failed.
            exit 1
        fi
        
    else 
        echo "[DEBUG] Running terraform without posting to GitHub"
        echo terraform "${INPUT_GLOBAL_ARGUMENTS}" "${command}" ${tf_args[@]}
        if ! terraform "${INPUT_GLOBAL_ARGUMENTS}" "${command}" ${tf_args[@]}; then
            echo terraform "${command}" failed.
            exit 1
        fi
    fi

    popd > /dev/null || exit
}

main "$@"
