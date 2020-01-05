# Cookielab - Deployer image

This image is based on [our Alpine Linux image](https://cloud.docker.com/u/cookielab/repository/docker/cookielab/alpine).

We make this image for deploying our applications from Gitlab to Kubernetes.

This image contains [`kubectl`](https://kubernetes.io/docs/reference/kubectl/overview/), [`terraform`](https://terraform.io), [`helm`](https://helm.sh/), [`sentry-cli`](https://docs.sentry.io/cli/) and [`kubeless`](https://kubeless.io/).
It also contains `kube-connect` script with will connect to your kubernetes cluser via env variables (standard one in Gitlab CI).

## Usage

```bash
# kubectl
docker run --rm cookielab/deployer:0.11
> kube-connect
> kubectl version

# terraform
docker run --rm cookielab/deployer:0.11 terraform version

# helm
docker run --rm cookielab/deployer:0.11
> kube-connect
> helm version

# sentry-cli
docker run --rm cookielab/deployer:0.11 sentry-cli --version

# kubeless
docker run --rm cookielab/deployer:0.11
> kube-connect
> kubeless version
```
