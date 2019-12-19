# gitlab-cicd-demo


## pre-reqs
```
#download helm3
#download kubectl
#download minikube
#download docker desktop
#download perl
```

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

## in another terminal window, make sure it all is running & ready (may take ~10 mins)
```
watch kubectl get po -n gitlab
#ctrl+c to exit
```

## trust gitlab registry certs for docker/minikube && restart
```
GITLABREGISTRY=$(k get -n gitlab ing gitlab-registry -o jsonpath="{.spec.rules[0].host}" && echo) && echo $GITLABREGISTRY
echo -n | openssl s_client -connect ${GITLABREGISTRY}:443 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ${GITLABREGISTRY}.crt
sudo mkdir -v /usr/local/share/ca-certificates/minikube/
sudo cp -pv ${GITLABREGISTRY}.crt /usr/local/share/ca-certificates/minikube/
sudo update-ca-certificates
sudo minikube stop
sudo systemctl stop docker
docker ps 
sudo systemctl start docker
sudo minikube start --vm-driver=none --kubernetes-version v1.15.3
```

## again in another terminal window, make sure it all restarts healthy
```
watch kubectl get po --all-namespaces
#ctrl+c to exit
#if any errors are still happening after 5-10 mins, do a "kubectl delete po name-of-the-pod -n namespace-name" for each pod with issues
```

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
--non-interactive \
--executor "docker" \
--docker-image "docker:19.03.1" \
--url "${GITURL}" \
--tls-ca-file "/etc/gitlab-runner/certs/ca.crt -n" \
--registration-token "${GITRUNREG}" \
--description "docker-runner" \
--tag-list "docker,local-runner" \
--run-untagged \
--docker-wait-for-services-timeout 60 \
--docker-volumes "/certs/client" \
--locked="false"
```

## restart the docker gitlab runner to make it active with the updated registered config
```
docker restart gitlab-runner
```

## SETUP MINIKUBE INTEGRATION
```
## create gitlabcicd service account
kubectl create sa gitlabcicd
kubectl create clusterrolebinding deployer --clusterrole cluster-admin --serviceaccount default:gitlabcicd
KUBE_DEPLOY_SECRET_NAME=`kubectl get sa gitlabcicd -o jsonpath='{.secrets[0].name}'` && echo $KUBE_DEPLOY_SECRET_NAME
CLUSTER_NAME=minikube
MINIKUBE_APISERVER=$(kubectl config view -o jsonpath="{.clusters[?(@.name=='$CLUSTER_NAME')].cluster.server}") && echo $APISERVER
MINIKUBE_USER_TOKEN=$(kubectl get secret $KUBE_DEPLOY_SECRET_NAME -o jsonpath='{.data.token}'|base64 --decode) && echo $MINIKUBE_USER_TOKEN
MINIKUBE_CA=$(kubectl config view -o jsonpath="{.clusters[?(@.name=='$CLUSTER_NAME')].cluster.certificate-authority}") && cat $MINIKUBE_CA
```

## USING VALUES FROM ABOVE, CREATE GITLAB CICD variables
```
#Under Project Settings > CICD > Variables
MINIKUBE_APISERVER
MINIKUBE_USER_TOKEN
MINIKUBE_CA
```

## STILL NEED TO DO...
## directions to import this repo to gitlab
## automate some of the manual stuff
## explain making change and pipeline work



## Useful links
https://docs.gitlab.com/ee/administration/troubleshooting/kubernetes_cheat_sheet.html#installation-of-minimal-gitlab-config-via-minukube-on-macos




## ALL DONE?? cleanup steps
```
helm delete -n gitlab gitlab
sudo minikube delete
docker rm --force gitlab-runner
sudo rm -rfv /srv/gitlab-runner/config/*
```
