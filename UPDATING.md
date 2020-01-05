# How to update this image?

1. check https://cloud.docker.com/u/cookielab/repository/docker/cookielab/alpine/tags if there is new version of base image
2. check https://github.com/kubernetes/kubernetes/releases if there is new version of kubectl and update it in `.gitlab-ci.yml`
3. check https://github.com/hashicorp/terraform/releases if there is new version of terraform and update it in `.gitlab-ci.yml`
4. check https://github.com/helm/helm/releases if there is new version of helm and update it in `.gitlab-ci.yml`
5. check https://github.com/kubeless/kubeless/releases if there is new version of kubeless and update it in `.gitlab-ci.yml`
6. update version in `README.md` if necessary and commit this change
7. make new tag with new version and push it to GitLab
