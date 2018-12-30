FROM cookielab/alpine:3.8

ARG KUBE_VERSION
ARG TERRAFORM_VERSION

RUN apk --update --no-cache add ca-certificates bash curl unzip && \
    curl -L https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl && \
    curl -L https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o ./terraform.zip && \
    unzip ./terraform.zip && \
    rm ./terraform.zip && \
    mv ./terraform /usr/local/bin/terraform && \
    chmod +x /usr/local/bin/terraform
