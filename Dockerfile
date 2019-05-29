FROM cookielab/alpine:3.9

ARG KUBE_VERSION
ARG TERRAFORM_VERSION
ARG HELM_VERSION

ADD kube-connect /usr/local/bin/kube-connect

RUN apk --update --no-cache add ca-certificates bash curl gzip unzip
RUN chmod +x /usr/local/bin/kube-connect
RUN curl -L https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl
RUN curl -L https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o ./terraform.zip
RUN unzip ./terraform.zip
RUN rm ./terraform.zip
RUN mv ./terraform /usr/local/bin/terraform
RUN chmod +x /usr/local/bin/terraform
RUN curl -L https://storage.googleapis.com/kubernetes-helm/helm-v${HELM_VERSION}-linux-amd64.tar.gz -o ./helm.tar.gz
RUN tar -xzf ./helm.tar.gz
RUN rm ./helm.tar.gz
RUN mv ./linux-amd64/helm /usr/local/bin/helm
RUN chmod +x /usr/local/bin/helm
RUN rm -rf ./linux-amd64
RUN curl -sL https://sentry.io/get-cli/ | bash

USER 1987
ONBUILD USER root
