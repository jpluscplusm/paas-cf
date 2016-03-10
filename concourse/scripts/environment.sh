#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(cd "${SCRIPT_DIR}/../.." && pwd)

hashed_password() {
  echo "$1" | shasum -a 256 | base64 | head -c 32
}

fetch_system_dns_zone(){
  awk -F' *= *|"' '$1=="system_dns_zone_name" { print $3}' "${PROJECT_DIR}/terraform/${AWS_ACCOUNT}.tfvars"
}

DEPLOY_ENV=${1:-${DEPLOY_ENV:-}}
if [ -z "${DEPLOY_ENV}" ]; then
  echo "Must specify DEPLOY_ENV as \$1 or environment variable" 1>&2
  exit 1
fi

AWS_ACCOUNT=${AWS_ACCOUNT:-dev}

case $TARGET_CONCOURSE in
  deployer)
    CONCOURSE_URL="https://deployer.${DEPLOY_ENV}.$(fetch_system_dns_zone)"
    FLY_TARGET=$DEPLOY_ENV
    FLY_CMD="${PROJECT_DIR}/bin/fly"
    ;;
  bootstrap)
    CONCOURSE_URL="http://localhost:8080"
    FLY_TARGET="${DEPLOY_ENV}-bootstrap"
    FLY_CMD="${PROJECT_DIR}/bin/fly-bootstrap"
    ;;
  *)
    echo "Unrecognized TARGET_CONCOURSE: '${TARGET_CONCOURSE}'. Must be set to 'deployer' or 'bootstrap'" 1>&2
    exit 1
    ;;
esac

CONCOURSE_ATC_USER=${CONCOURSE_ATC_USER:-admin}
if [ -z "${CONCOURSE_ATC_PASSWORD:-}" ]; then
  CONCOURSE_ATC_PASSWORD=$(hashed_password "${AWS_SECRET_ACCESS_KEY}:${DEPLOY_ENV}:atc")
fi

cat <<EOF
export AWS_ACCOUNT=${AWS_ACCOUNT}
export DEPLOY_ENV=${DEPLOY_ENV}
export CONCOURSE_ATC_USER=${CONCOURSE_ATC_USER}
export CONCOURSE_ATC_PASSWORD=${CONCOURSE_ATC_PASSWORD}
export CONCOURSE_URL=${CONCOURSE_URL}
export FLY_CMD=${FLY_CMD}
export FLY_TARGET=${FLY_TARGET}
EOF

echo "Deploy environment name: $DEPLOY_ENV" 1>&2
echo "Concourse URL is ${CONCOURSE_URL}" 1>&2
echo "Concourse auth is ${CONCOURSE_ATC_USER} : ${CONCOURSE_ATC_PASSWORD}" 1>&2
