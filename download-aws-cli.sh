#!/bin/sh

set -xe

TARGETARCH_ALT=$(echo "${TARGETARCH}" | sed s/arm64/aarch64/ | sed s/amd64/x86_64/)

curl -L "https://awscli.amazonaws.com/awscli-exe-linux-${TARGETARCH_ALT}-${AWS_CLI_VERSION}.zip" -o /tmp/awscliv2.zip
unzip /tmp/awscliv2.zip
