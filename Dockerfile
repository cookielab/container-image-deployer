FROM cookielab/alpine:3.13

ARG KUBE_VERSION
ARG HELM_VERSION
ARG SENTRY_CLI_VERSION

ADD kube-connect /usr/local/bin/kube-connect

RUN apk --update --no-cache add ca-certificates openssh bash curl gzip unzip git jq
RUN chmod +x /usr/local/bin/kube-connect
RUN curl -L https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl
RUN curl -L https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz -o ./helm.tar.gz
RUN tar -xzf ./helm.tar.gz
RUN rm ./helm.tar.gz
RUN mv ./linux-amd64/helm /usr/local/bin/helm
RUN chmod +x /usr/local/bin/helm
RUN rm -rf ./linux-amd64
RUN curl -L https://downloads.sentry-cdn.com/sentry-cli/${SENTRY_CLI_VERSION}/sentry-cli-Linux-x86_64 -o ./sentry-cli
RUN mv ./sentry-cli /usr/local/bin/sentry-cli
RUN chmod +x /usr/local/bin/sentry-cli

USER 1987

RUN mkdir -p -m 0700 /container/.ssh
RUN touch /container/.ssh/known_hosts
RUN chmod 0644 /container/.ssh/known_hosts

ONBUILD USER root
