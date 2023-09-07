#!/bin/sh

help() {
  echo "Usage: $0 [-h] [-v] -s <SOURCE_DIR> -u <AWS_S3_BUCKET_URI> -i <AWS_CF_DISTRIBUTION_ID>"
  echo ""
  echo "Options:"
  echo "  -s SOURCE_DIR"
  echo "        Local source directory"
  echo "        REQUIRED (Can be also provided via environment variable)"
  echo "  -u AWS_S3_BUCKET_URI"
  echo "        AWS S3 bucket URI in the following format: 's3://<bucket>/[<subdir>]'"
  echo "        REQUIRED (Can be also provided via environment variable or constructed. See below)"
  echo "  -i AWS_CF_DISTRIBUTION_ID"
  echo "        AWS CloudFront Distribution ID"
  echo "        REQUIRED (Can be also provided via environment variable)"
  echo "  -v    Verbose output (print API commands being executed)"
  echo "  -h    Display this help message"
  echo ""
  echo "Other supported environment variables:"
  echo "  AWS_S3_BUCKET  Can be used to construct the S3 bucket URI."
  echo "                 If used, AWS_S3_BUCKET_URI doesn't have to be set."
  echo "  AWS_S3_PATH    Can be used to further specify bucket path in the S3 URI."
  echo "                 Has to start with '/'. Works only when AWS_S3_BUCKET is set."
  echo "                 Defaults to '/'."
}

# Format functions
log() {
  if [ $# -eq 2 ]; then
    printf -- "--> %-28s %s\n" "${1}:" "$2" >&2
  else
    echo "$@" >&2
  fi
}

banner() {
  echo ">>> $*" >&2
}

fail() {
  echo "==> $*" >&2
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
  ret=$?; set +x
  return ${ret}
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
  val=$(aws cloudfront create-invalidation --distribution-id "${cf_dist_id}" --paths '/*' --output json)
  ret=$?; set +x
  test "${ret}" -eq 0 && (echo "${val}" | jq -r .Invalidation.Id)
  return ${ret}
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
  ret=$?; set +x
  return ${ret}
}

##################
### Initialize ###
##################

set -e
OPTIND=1
VERBOSE=0
ERR=0

# Use the optional input variables when defined
test -n "${AWS_S3_BUCKET}" && AWS_S3_BUCKET_URI="s3://${AWS_S3_BUCKET}${AWS_S3_PATH:-/}"

# Parse command line
while getopts "h?s:u:i:v?" opt; do
  case "${opt}" in
    h) help && exit 0 ;;
    s) SOURCE_DIR="${OPTARG}" ;;
    u) AWS_S3_BUCKET_URI="${OPTARG}" ;;
    i) AWS_CF_DISTRIBUTION_ID="${OPTARG}" ;;
    v) VERBOSE=1 ;;
    *) echo && help && exit 1 ;;
  esac
done

# Test if required variables are set
test -z "${SOURCE_DIR}" && log "No SOURCE_DIR (-s) provided" && ERR=1
test -z "${AWS_S3_BUCKET_URI}" && log "No AWS_S3_BUCKET_URI (-u) provided" && ERR=1
test -z "${AWS_CF_DISTRIBUTION_ID}" && log "No AWS_CF_DISTRIBUTION_ID (-i) provided" && ERR=1
test "${ERR}" -gt 0 && echo && help && false

# Test if AWS_S3_PATH is valid (when provided)
if [ -n "${AWS_S3_PATH}" ] && ! (echo "${AWS_S3_PATH}" | grep -Eq '^/')
then
  fail "Invalid AWS S3 Bucket path: '${AWS_S3_PATH}' (needs to start with '/')"
fi

# Test if AWS_S3_BUCKET_URI is valid
if ! (echo "${AWS_S3_BUCKET_URI}" | grep -Eq '^s3://[a-zA-Z0-9._-]+/')
then
  fail "Invalid AWS S3 Bucket URI: '${AWS_S3_BUCKET_URI}' (needs to be in the following format: 's3://<bucket>/[<subdir>]')"
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
