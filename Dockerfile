FROM cookielab/slim:12.10 AS build

ARG TARGETARCH
WORKDIR /tmp

RUN apt update && apt install -y curl zip

ARG KUBECTL_VERSION
RUN curl -L "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" -o /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl

ARG HELM_VERSION
RUN curl -L "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" -o /tmp/helm.tar.gz
RUN tar -xzf /tmp/helm.tar.gz
RUN rm /tmp/helm.tar.gz
RUN mv /tmp/linux-${TARGETARCH}/helm /usr/local/bin/helm
RUN chmod +x /usr/local/bin/helm

ARG SENTRY_CLI_VERSION
RUN curl -sL https://sentry.io/get-cli/ | INSTALL_DIR="/usr/local/bin" sh

ARG AWS_CLI_VERSION
COPY build-scripts/download-aws-cli.sh /tmp/download-aws-cli.sh
RUN /tmp/download-aws-cli.sh

COPY scripts/assume-role.sh /usr/local/bin/assume-role
COPY scripts/deploy-s3-cf.sh /usr/local/bin/deploy-s3-cf
COPY scripts/helm-rollback.sh /usr/local/bin/helm-rollback

FROM cookielab/container-image-tools:1.9.1-aws AS container-image-tools

FROM cookielab/slim:12.10

RUN apt update && apt install -y curl jq skopeo git gettext-base procps zip \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/bin /usr/local/bin

COPY --from=build /tmp/aws /tmp/aws
RUN /tmp/aws/install
RUN rm -rf /tmp/aws

RUN mkdir ~/.docker
COPY --from=container-image-tools /container-image-tools/bin/docker-* /usr/local/bin/
COPY --from=container-image-tools /etc/containers/policy.json /etc/containers/policy.json
COPY registries.conf /etc/containers/registries.conf

USER 1987

ONBUILD USER root
