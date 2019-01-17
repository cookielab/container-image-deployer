FROM cookielab/alpine:3.8

ARG KUBE_VERSION
ARG TERRAFORM_VERSION
ARG HELM_VERSION

ADD kube-connect /usr/local/bin/kube-connect

RUN apk --update --no-cache add ca-certificates bash curl gzip unzip && \
    chmod +x /usr/local/bin/kube-connect
RUN curl -L https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl
RUN curl -L https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o ./terraform.zip && \
    unzip ./terraform.zip && \
    rm ./terraform.zip && \
    mv ./terraform /usr/local/bin/terraform && \
    chmod +x /usr/local/bin/terraform
RUN curl -L https://storage.googleapis.com/kubernetes-helm/helm-v${HELM_VERSION}-linux-amd64.tar.gz -o ./helm.tar.gz && \
    tar -xzf ./helm.tar.gz && \
    rm ./helm.tar.gz && \
    mv ./linux-amd64/helm /usr/local/bin/helm && \
    chmod +x /usr/local/bin/helm && \
    rm -rf ./linux-amd64

USER 1987
ONBUILD USER root
