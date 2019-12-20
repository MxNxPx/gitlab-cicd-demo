# gitlab-cicd-demo
do not do this in a Production environment, this is for demo only!


## PRE-REQS

### install locally
```
#MAC or LINUX
#RAM: about 8GB free
#DISK: about 20GB free
#INTERNET ACCESS
#download helm3
#download kubectl
#download minikube
#download docker desktop
#download perl
```

### clone this repo & cd into it
```
git clone https://github.com/MxNxPx/gitlab-cicd-demo gitlab-cicd-demo && cd $_
```

### setup minikube
```
sudo minikube start --vm-driver=none --kubernetes-version v1.15.3
sudo minikube addons enable ingress
sudo chown -R $USER:$USER ~/.minikube/
```


## DEPLOY GITHUB

### setup namespace for gitlab in minikube
```
kubectl create ns gitlab
```

### add helm repo for gitlab
```
helm repo add gitlab https://charts.gitlab.io/
## (optional) gitlab helm package - download to view locally
#helm fetch gitlab/gitlab
#tar -zxvf gitlab-*.tgz
```

### using helm, install gitlab to minikube
```
MINI_IP=$(sudo minikube ip)
helm upgrade --install gitlab gitlab/gitlab \
   --namespace gitlab \
   --timeout 600s \
   --set global.hosts.domain=$MINI_IP.nip.io \
   --set global.hosts.externalIP=$MINI_IP \
   -f https://gitlab.com/gitlab-org/charts/gitlab/raw/master/examples/values-minikube-minimum.yaml
```

### in another terminal window, make sure it all is running & ready (may take ~10 mins)
```
watch kubectl get po -n gitlab
#ctrl+c to exit
```


## MINIKUBE / GITLAB CONFIG

### trust gitlab registry certs for docker/minikube && restart
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

### again in another terminal window, make sure it all restarts healthy
```
watch kubectl get po --all-namespaces
#ctrl+c to exit
#if any pods are not "Running" or "Completed" (such as "RunContainerError" or "CrashLoopBackOff") after 5-10 mins, run this command
#kubectl -n gitlab get pods | egrep -v "NAME|Running|Completed" | awk '{print $1}' | xargs kubectl -n gitlab delete pod
```

### get runner registration token
```
GITRUNREG=$(sh get-runner-reg.sh) && echo $GITRUNREG
```

### launch gitlab runner as local docker container
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

### create certs dir under docker volume & pull down gitlab ca cert from k8s into certs dir for docker container
```
sudo mkdir /srv/gitlab-runner/config/certs && \
kubectl get secrets/gitlab-wildcard-tls-ca -n gitlab -o "jsonpath={.data['cfssl_ca']}" | base64 --decode > /tmp/ca.crt && \
sudo mv /tmp/ca.crt /srv/gitlab-runner/config/certs
```

### register the docker gitlab runner
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

### restart the docker gitlab runner to make it active with the updated registered config
```
docker restart gitlab-runner
```


## SETUP MINIKUBE INTEGRATION


### get & set vars for gitlab url & root password for UI
#### NOTE: store the output as you will need it for the UI steps below
```
GITUSER="root"
GITURL=$(echo -n "https://" ; kubectl -n gitlab get ingress gitlab-unicorn -ojsonpath='{.spec.rules[0].host}' ; echo) && echo $GITURL
GITROOTPWD=$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode ; echo) && echo $GITROOTPWD
```

### create service account and grab cicd values needed for deploy step
#### NOTE: store the output as you will need it for the UI steps below
```
## create gitlabcicd service account
kubectl create sa gitlabcicd
kubectl create clusterrolebinding deployer --clusterrole cluster-admin --serviceaccount default:gitlabcicd
KUBE_DEPLOY_SECRET_NAME=`kubectl get sa gitlabcicd -o jsonpath='{.secrets[0].name}'` && echo $KUBE_DEPLOY_SECRET_NAME
CLUSTER_NAME=minikube
MINIKUBE_APISERVER=$(kubectl config view -o jsonpath="{.clusters[?(@.name=='$CLUSTER_NAME')].cluster.server}") && echo $MINIKUBE_APISERVER
MINIKUBE_USER_TOKEN=$(kubectl get secret $KUBE_DEPLOY_SECRET_NAME -o jsonpath='{.data.token}'|base64 --decode) && echo $MINIKUBE_USER_TOKEN
MINIKUBE_CA=$(kubectl config view -o jsonpath="{.clusters[?(@.name=='$CLUSTER_NAME')].cluster.certificate-authority}") && cat $MINIKUBE_CA
```


## GITLAB UI SETUP

### login to UI (using root/$GITROOTPWD) create gitlab-cicd-demo project
```
open ${GITURL} &
#on linux
#google-chrome ${GITURL} &

#Under Create New Project > Import Project > Repo by URL
#Paste this repo URL: https://github.com/MxNxPx/gitlab-cicd-demo.git
#Project name: gitlab-cicd-demo
#Project slug: gitlab-cicd-demo
#Visibility level: Public
```

### using values from above, create gitlab cicd variables needed for deploy
```
#Under Project Settings > CICD > Variables
#Variable: MINIKUBE_APISERVER $MINIKUBE_APISERVER
#Variable: MINIKUBE_USER_TOKEN $MINIKUBE_USER_TOKEN
#File: MINIKUBE_CA $MINIKUBE_CA
```


## KICK OFF A PIPELINE

### setup terminal window to watch kubernetes for deployment
```
watch kubectl get po -n gitlab
#ctrl+c to exit
```

### edit a project file
```
#Prepare a browser tab to watch the pipeline
#Under gitlab-cicd-demo project (left nav) > CICD > Pipelines
#Open another browser tab to make a change
#Under gitlab-cicd-demo project (left nav) > Repository > Files
#Click the .gitlab-ci.yml file
#Click Edit
#Scroll to bottom and click "Commit Changes"
```

### watch the pipeline run!
```
#In the pipeline tab an entry should appear in running state
#Click into that and see all the steps it plans to run
#Click into each step to watch progress
#Before the deploy step runs, pop over to the terminal with the "watch" command running to see it deploy
```

### verify the deploy worked
```
open $(sudo minikube ip):8080 &
#on linux
#google-chrome $(sudo minikube ip):8080 &
```



## ADDITIONAL INFO

### Useful links
https://docs.gitlab.com/ee/administration/troubleshooting/kubernetes_cheat_sheet.html#installation-of-minimal-gitlab-config-via-minukube-on-macos


### ALL DONE?? cleanup steps
```
helm delete -n gitlab gitlab
sudo minikube delete
docker rm --force gitlab-runner
sudo rm -rfv /srv/gitlab-runner/config/*
#BEWARE! command below will wipe ALL local docker containers and data
docker system prune -a
```
