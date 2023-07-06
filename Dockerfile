FROM cookielab/slim:12.0 AS build

ARG TARGETARCH
WORKDIR /tmp

RUN apt update && apt install -y curl zip

ARG KUBECTL_VERSION
RUN curl -L "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" -o /usr/local/kubectl
RUN chmod +x /usr/local/kubectl

ARG HELM_VERSION
RUN curl -L "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" -o /tmp/helm.tar.gz
RUN tar -xzf /tmp/helm.tar.gz
RUN rm /tmp/helm.tar.gz
RUN mv /tmp/linux-${TARGETARCH}/helm /usr/local/bin/helm
RUN chmod +x /usr/local/bin/helm

ARG SENTRY_CLI_VERSION
RUN curl -sL https://sentry.io/get-cli/ | INSTALL_DIR="/usr/local/bin" sh

ARG AWS_CLI_VERSION
COPY download-aws-cli.sh /tmp/download-aws-cli.sh
RUN /tmp/download-aws-cli.sh

FROM cookielab/slim:12.0

RUN apt update && apt install -y curl jq \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/bin /usr/local/bin

COPY --from=build /tmp/aws /tmp/aws
RUN /tmp/aws/install
RUN rm -rf /tmp/aws

ARG GITHUB_TOKEN

USER 1987

ONBUILD USER root
