# gitlab-cicd-demo
gitlab cicd demo

## pre-reqs
#download helm3
#download kubectl
#download minikube
#download docker desktop
#download perl
https://docs.gitlab.com/ee/administration/troubleshooting/kubernetes_cheat_sheet.html#installation-of-minimal-gitlab-config-via-minukube-on-macos


## clone this repo & cd into it
```
git clone https://github.com/MxNxPx/gitlab-cicd-demo gitlab-cicd-demo && cd $_
```

## setup minikube
```
sudo minikube start --vm-driver=none --kubernetes-version v1.15.3
sudo minikube addons enable ingress
sudo chown -R $USER:$USER ~/.minikube/
```

## setup namespace for gitlab
```
kubectl create ns gitlab
```

## add helm repo for gitlab
```
helm repo add gitlab https://charts.gitlab.io/
## (optional) gitlab helm package - download to view locally
#helm fetch gitlab/gitlab
#tar -zxvf gitlab-*.tgz
```

## install gitlab
```
helm upgrade --install gitlab gitlab/gitlab \
   --namespace gitlab \
   --timeout 600s \
   --set global.hosts.domain=$(minikube ip).nip.io \
   --set global.hosts.externalIP=$(minikube ip) \
   -f https://gitlab.com/gitlab-org/charts/gitlab/raw/master/examples/values-minikube.yaml
```

## make sure it all is running & ready (may take ~10 mins)
```
watch kubectl get po -n gitlab
#ctrl+c to exit
```

## create personal access token for api usage


## get & set vars for gitlab url & root password for UI
```
GITUSER="root"
GITURL=$(echo -n "https://" ; kubectl -n gitlab get ingress gitlab-unicorn -ojsonpath='{.spec.rules[0].host}' ; echo) && echo $GITURL
GITROOTPWD=$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode ; echo) && echo $GITROOTPWD
```

## get runner registration token
```
GITRUNREG=$(sh get-runner-reg.sh) && echo $GITRUNREG
```

## if step above didn't work - MANUALLY get & set runner registration token - open browser, using root & ${GITROOTPWD}
```
open ${GITURL}/admin/runners
#on linux
#google-chrome ${GITURL}/admin/runners
## set variable using the copied registration token
read -p "Paste registration token: " GITRUNREG
```

## launch gitlab runner as local docker container
```
docker run \
--privileged \
--detach \
--name gitlab-runner \
--restart always \
-v /srv/gitlab-runner/config:/etc/gitlab-runner \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /cache \
gitlab/gitlab-runner:latest
```

## create certs dir under docker volume & pull down gitlab ca cert from k8s into certs dir for docker container
```
sudo mkdir /srv/gitlab-runner/config/certs && \
kubectl get secrets/gitlab-wildcard-tls-ca -n gitlab -o "jsonpath={.data['cfssl_ca']}" | base64 --decode > /tmp/ca.crt && \
sudo mv /tmp/ca.crt /srv/gitlab-runner/config/certs
```

## register the docker gitlab runner
```
docker run -v /srv/gitlab-runner/config:/etc/gitlab-runner --rm -t -i gitlab/gitlab-runner register \
--docker-privileged \
--cache-dir /cache \
--non-interactive \
--executor "docker" \
--docker-image alpine:latest \
--url "${GITURL}" \
--tls-ca-file "/etc/gitlab-runner/certs/ca.crt -n" \
--registration-token "${GITRUNREG}" \
--description "docker-runner" \
--tag-list "docker,local-runner" \
--run-untagged \
--locked="false" \
--docker-volumes '/var/run/docker.sock:/var/run/docker.sock'
```

## restart the docker gitlab runner to make it active with the updated registered config
```
docker restart gitlab-runner
```

## STILL NEED TO DO...
## import a repo to gitlab, make a change, and watch it run thru cicd



## ALL DONE?? cleanup steps
```
helm delete -n gitlab gitlab
sudo minikube delete
docker rm --force gitlab-runner
sudo rm -rfv /srv/gitlab-runner/config/*
```
