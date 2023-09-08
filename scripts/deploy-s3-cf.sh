#!/bin/sh

help() {
  echo "Usage: $0 [-h] [-v] [-c] -s <SOURCE_DIR> -u <AWS_S3_BUCKET_URI> -i <AWS_CF_DISTRIBUTION_ID>"
  echo
  echo "Options:"
  echo "  -s SOURCE_DIR"
  echo "        Local source directory"
  echo "        REQUIRED (Can be also provided via environment variable)"
  echo "  -u AWS_S3_BUCKET_URI"
  echo "        AWS S3 bucket URI in the following format: 's3://<bucket>/[<subdir>]'"
  echo "        REQUIRED (Can be also provided via environment variable or"
  echo "        constructed from optional variables - see below)"
  echo "  -i AWS_CF_DISTRIBUTION_ID"
  echo "        AWS CloudFront Distribution ID"
  echo "        REQUIRED (Can be also provided via environment variable)"
  echo "  -c    Enable color output. Defaults to autodetection from TERM."
  echo "  -v    Enable verbose output (print API commands being executed)."
  echo "  -h    Display this help message"
  echo
  echo "Other environment variables:"
  echo "  AWS_S3_BUCKET  Can be used to construct the S3 bucket URI."
  echo "                 If used, AWS_S3_BUCKET_URI doesn't have to be set."
  echo "  AWS_S3_PATH    Can be used to further specify bucket path in the S3 URI."
  echo "                 Has to start with '/'. Works only when AWS_S3_BUCKET is set."
  echo "                 Defaults to '/'."
  echo "  COLORIZE       Set to 1 to enable color output (or use -c). Set to 0 to disable."
  echo "                 By default it's autodetected from TERM."
  echo "  VERBOSE        Set to 1 to enable verbose output (or use -v). Defaults to 0."
}

# Format functions
log() {
  if [ $# -eq 2 ]; then
    _fmt="\033[32;3m--> \033[2m\033[32;2m%-28s\033[0m \033[34;5m%s\033[0m\n"
    test "${COLORIZE}" -eq 0 && _fmt="--> %-28s %s\n"
    printf -- "${_fmt}" "${1}:" "$2" >&2
  else
    _fmt="\033[31;3m%s\033[0m\n"
    test "${COLORIZE}" -eq 0 && _fmt="%s\n"
    printf -- "${_fmt}" "${@}" >&2
  fi
}

banner() {
  _fmt="\033[32;1m>>> \033[3m%s\033[0m\n"
  test "${COLORIZE}" -eq 0 && _fmt=">>> %s\n"
  printf -- "${_fmt}" "${@}" >&2
}

fail() {
  _fmt="\033[31;1m==> \033[3m%s\033[0m\n"
  test "${COLORIZE}" -eq 0 && _fmt="==> %s\n"
  printf -- "${_fmt}" "${@}" >&2
  return 1
}

# S3: Deploy
# ==========
# Wrapper to recursively copy the source directory to
# the S3 bucket URI
#
# Requires:
# - source directory
#     (-s / $SOURCE_DIR)
# - AWS S3 Bucket URI
#     (-u / $AWS_S3_BUCKET_URI)
#
s3_deploy() {
  src_dir="${1}"
  s3_uri="${2}"
  s3_bucket=$(echo "${s3_uri}" | awk -F/ '{print $3}')
  s3_dir=/$(echo "${s3_uri}" \
    | awk -F/ 'BEGIN { OFS="/"; ORS=""; } { for (i=4; i<=NF; i++) printf "%s%s", $i, (i<NF ? OFS : ORS)}' \
    | sed 's|/*$||')
  log "Source directory" "${src_dir}"
  log "Destination S3 Bucket name" "${s3_bucket}"
  log "Destination S3 Bucket path" "${s3_dir}"
  cmd_opts="--recursive"
  test "${VERBOSE}" -gt 0 && set -x
  aws s3 cp ${cmd_opts} "${src_dir}" "s3://${s3_bucket}${s3_dir}"
  _ret=$?; set +x
  return ${_ret}
}

# CloudFront: Invalidate
# ======================
# Wrapper to trigger and retrieve the Invalidation ID
# for the `cf_wait` function.
#
# Requires:
# - AWS CloudFront Distribution ID
#     (-i / $AWS_CF_DISTRIBUTION_ID)
#
cf_invalidate() {
  cf_dist_id="${1}"
  log "CloudFront Distribution ID" "${cf_dist_id}"
  test "${VERBOSE}" -gt 0 && set -x
  _val=$(aws cloudfront create-invalidation --distribution-id "${cf_dist_id}" --paths '/*' --output json)
  _ret=$?; set +x
  test "${_ret}" -eq 0 && (echo "${_val}" | jq -r .Invalidation.Id)
  return ${_ret}
}

# CloudFront: Wait
# ================
# This just waits for the CloudFront Invalidation
# to finish.
#
# Requires:
# - AWS CloudFront Distribution ID
#     (-i / $AWS_CF_DISTRIBUTION_ID)
# - AWS CloudFront Invalidation ID
#     (value from cf_invalidate)
#
cf_wait() {
  cf_dist_id="${1}"
  cf_inv_id="${2}"
  log "CloudFront Invalidation ID" "${cf_inv_id}"
  test "${VERBOSE}" -gt 0 && set -x
  aws cloudfront wait invalidation-completed --distribution-id "${cf_dist_id}" --id "${cf_inv_id}"
  _ret=$?; set +x
  return ${_ret}
}

##################
### Initialize ###
##################

set -e
OPTIND=1
ERR=0
VERBOSE=${VERBOSE:-0}

# Colorize autodetection
[ "${CI}" = "true" ] && COLORIZE=${COLORIZE:-1}
case "${TERM}" in
  *color|[kK]itty*|[aA]lacritty|[xXaAeEiI][tT]erm*)
     COLORIZE=${COLORIZE:-1} ;;
  *) COLORIZE=${COLORIZE:-0} ;;
esac

# Use the optional input variables when defined
test -n "${AWS_S3_BUCKET}" && AWS_S3_BUCKET_URI="s3://${AWS_S3_BUCKET}${AWS_S3_PATH:-/}"

# Parse command line
while getopts "h?s:u:i:v?c?" opt; do
  case "${opt}" in
    h) help && exit 0 ;;
    s) SOURCE_DIR="${OPTARG}" ;;
    u) AWS_S3_BUCKET_URI="${OPTARG}" ;;
    i) AWS_CF_DISTRIBUTION_ID="${OPTARG}" ;;
    c) COLORIZE=1 ;;
    v) VERBOSE=1 ;;
    *) echo && help && exit 1 ;;
  esac
done

# Test if required variables are set
test -z "${SOURCE_DIR}" && log "No SOURCE_DIR (-s) provided" && ERR=1
test -z "${AWS_S3_BUCKET_URI}" && log "No AWS_S3_BUCKET_URI (-u) provided" && ERR=1
test -z "${AWS_CF_DISTRIBUTION_ID}" && log "No AWS_CF_DISTRIBUTION_ID (-i) provided" && ERR=1
test "${ERR}" -gt 0 && echo && help && false

# Validate AWS_S3_PATH (when provided)
if [ -n "${AWS_S3_BUCKET}" ] && [ -n "${AWS_S3_PATH}" ] && ! (echo "${AWS_S3_PATH}" | grep -Eq '^/')
then
  log "Invalid AWS_S3_PATH: '${AWS_S3_PATH}' does NOT start with '/'"
  false
fi

# Validate AWS_S3_BUCKET_URI
if ! (echo "${AWS_S3_BUCKET_URI}" | grep -Eq '^s3://[a-zA-Z0-9._-]+/')
then
  log "Invalid AWS_S3_BUCKET_URI (-u): '${AWS_S3_BUCKET_URI}' does NOT follow format 's3://<bucket>/[<subdir>]'"
  false
fi

############
### Main ###
############

banner "Deploy to S3 (running)"
s3_deploy "${SOURCE_DIR}" "${AWS_S3_BUCKET_URI}" \
  || fail "Deploy to S3 (failed)"
banner "Deploy to S3 (finished)"

banner "Invalidate in CloudFront (running)"
AWS_CF_INVALIDATION_ID=$(cf_invalidate "${AWS_CF_DISTRIBUTION_ID}" \
  || fail "Invalidate in CloudFront (failed on request)")
cf_wait "${AWS_CF_DISTRIBUTION_ID}" "${AWS_CF_INVALIDATION_ID}" \
  || fail "Invalidate in CloudFront (failed on wait)"
banner "Invalidate in CloudFront (finished)"
