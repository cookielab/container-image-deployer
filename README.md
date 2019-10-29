# Cookielab - Deployer image

This image is based on [our Alpine Linux image](https://cloud.docker.com/u/cookielab/repository/docker/cookielab/alpine).

We make this image for deploying our applications from Gitlab to Kubernetes.

This image contains [`kubectl`](https://kubernetes.io/docs/reference/kubectl/overview/), [`terraform`](https://terraform.io) and [`helm`](https://helm.sh/).
It also contains `kube-connect` script with will connect to your kubernetes cluser via env variables (standard one in Gitlab CI).

## Usage

```
# kubectl
docker run --rm cookielab/deployer:0.8
> kube-connect
> kubectl version

# terraform
docker run --rm cookielab/deployer:0.8 terraform version

# helm
docker run --rm cookielab/deployer:0.8
> kube-connect
> helm version
```
