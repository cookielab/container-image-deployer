# cookielab/deployer

- [kubectl](https://kubernetes.io/docs/reference/kubectl/kubectl/)
- [helm](https://helm.sh/)
- [sentry-cli](https://docs.sentry.io/product/cli/)
- [aws-cli](https://aws.amazon.com/cli/)

## Scripts

- `deploy-s3-cf` - for deploying static site to S3 and CloudFront
- `assume-role` - Script for AssumeRoleWithWebIdentity
    - Requirements:
        - `$AWS_ROLE_ARN` = ENV variable for Role ARN
        - `$AWS_ROLE_SESSION_NAME` = ENV variable for session name
        - `$OIDC_TOKEN` = ENV variable for providing OIDC token
