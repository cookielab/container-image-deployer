#!/bin/bash

export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SESSION_EXPIRATION

read -r AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SESSION_EXPIRATION < <(
    aws sts assume-role-with-web-identity \
        --role-arn "${AWS_ROLE_ARN}" \
        --role-session-name "${AWS_ROLE_SESSION_NAME}" \
        --web-identity-token "${OIDC_TOKEN}" \
        --duration-seconds 900 \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken,Expiration]' \
        --output text
)

