FROM cookielab/alpine:3.11

ARG KUBE_VERSION
ARG TERRAFORM_VERSION
ARG HELM_VERSION
ARG KUBELESS_VERSION

ADD kube-connect /usr/local/bin/kube-connect

RUN apk --update --no-cache add ca-certificates openssh bash curl gzip unzip git
RUN chmod +x /usr/local/bin/kube-connect
RUN curl -L https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl
RUN curl -L https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o ./terraform.zip
RUN unzip ./terraform.zip
RUN rm ./terraform.zip
RUN mv ./terraform /usr/local/bin/terraform
RUN chmod +x /usr/local/bin/terraform
RUN curl -L https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz -o ./helm.tar.gz
RUN tar -xzf ./helm.tar.gz
RUN rm ./helm.tar.gz
RUN mv ./linux-amd64/helm /usr/local/bin/helm
RUN chmod +x /usr/local/bin/helm
RUN rm -rf ./linux-amd64
RUN curl -sL https://sentry.io/get-cli/ | bash
RUN curl -L https://github.com/kubeless/kubeless/releases/download/v${KUBELESS_VERSION}/kubeless_linux-amd64.zip -o /kubeless.zip
RUN unzip ./kubeless.zip
RUN rm ./kubeless.zip
RUN mv ./bundles/kubeless_linux-amd64/kubeless /usr/local/bin/kubeless
RUN chmod +x /usr/local/bin/kubeless
RUN rm -rf ./bundles

USER 1987

RUN mkdir -p -m 0700 /container/.ssh
RUN touch /container/.ssh/known_hosts
RUN chmod 0644 /container/.ssh/known_hosts

ONBUILD USER root
