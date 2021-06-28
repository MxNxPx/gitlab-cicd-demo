# gitlab-cicd-demo
do not do this in a Production environment, this is for demo only!


## Table of Contents
- [gitlab-cicd-demo](#gitlab-cicd-demo)
  * [PRE-REQS](#pre-reqs)
    + [install locally](#install-locally)
    + [start multipass, shell in, switch to root, clone this repo, and cd into it](#clone-this-repo-and-cd-into-it)
    + [setup minikube](#setup-minikube)
  * [DEPLOY GITLAB](#deploy-gitlab)
    + [setup namespace for gitlab in minikube](#setup-namespace-for-gitlab-in-minikube)
    + [add helm repo for gitlab](#add-helm-repo-for-gitlab)
    + [using helm - install gitlab to minikube](#using-helm---install-gitlab-to-minikube)
    + [in another terminal window - make sure it all is running and ready](#in-another-terminal-window---make-sure-it-all-is-running-and-ready)
  * [MINIKUBE AND GITLAB CONFIG](#minikube-and-gitlab-config)
    + [trust gitlab registry certs for docker and minikube](#trust-gitlab-registry-certs-for-docker-and-minikube)
    + [stop minikube and docker](#stop-minikube-and-docker)
    + [start docker and minikube](#start-docker-and-minikube)
    + [again in another terminal window - make sure it all restarts healthy](#again-in-another-terminal-window---make-sure-it-all-restarts-healthy)
    + [get runner registration token](#get-runner-registration-token)
    + [launch gitlab runner as local docker container](#launch-gitlab-runner-as-local-docker-container)
    + [create certs dir under docker volume and pull down gitlab ca cert from k8s into certs dir for docker container](#create-certs-dir-under-docker-volume-and-pull-down-gitlab-ca-cert-from-k8s-into-certs-dir-for-docker-container)
    + [register the docker gitlab runner](#register-the-docker-gitlab-runner)
    + [restart the docker gitlab runner to make it active with the updated registered config](#restart-the-docker-gitlab-runner-to-make-it-active-with-the-updated-registered-config)
  * [SETUP MINIKUBE INTEGRATION](#setup-minikube-integration)
    + [get and set vars for gitlab url - user root and root password for UI](#get-and-set-vars-for-gitlab-url---user-root-and-root-password-for-ui)
      - [NOTE: store the output as you will need it for the UI steps below](#note--store-the-output-as-you-will-need-it-for-the-ui-steps-below)
    + [create service account and grab cicd values needed for deploy step](#create-service-account-and-grab-cicd-values-needed-for-deploy-step)
      - [NOTE: store the output as you will need it for the UI steps below](#note--store-the-output-as-you-will-need-it-for-the-ui-steps-below-1)
  * [GITLAB UI SETUP](#gitlab-ui-setup)
    + [login to UI using root and GITROOTPWD create gitlab-cicd-demo project](#login-to-ui-using-root-and-gitrootpwd-create-gitlab-cicd-demo-project)
    + [using values from above - create gitlab cicd variables needed for deploy](#using-values-from-above---create-gitlab-cicd-variables-needed-for-deploy)
  * [KICK OFF A PIPELINE](#kick-off-a-pipeline)
    + [setup terminal window to watch kubernetes for deployment](#setup-terminal-window-to-watch-kubernetes-for-deployment)
    + [edit a project file](#edit-a-project-file)
    + [watch the pipeline run](#watch-the-pipeline-run)
    + [see your hello world page](#see-your-hello-world-page)
    + [change something and watch pipeline run again](#change-something-and-watch-pipeline-run-again)
  * [ADDITIONAL INFO](#additional-info)
    + [Useful links](#useful-links)
    + [ALL DONE - cleanup steps](#all-done---cleanup-steps)




## PRE-REQS

### highly suggest using [multipass](MULTIPASS.md)
### or
### install locally (UBUNTU ONLY)
```
#UBUNTU (18.04)
#RAM: about 8GB free
#DISK: about 30GB free
#INTERNET ACCESS
#install latest version of these tools
# - git
# - helm3
# - kubectl
# - minikube
# - docker desktop
# - curl
# - perl
# - jq
#handy browser addon to copy code blocks: https://github.com/zenorocha/codecopy
```

### start multipass, shell in, switch to root, clone this repo, and cd into it
```
bash multipass-setup.sh
multipass shell ubuntu-multipass
sudo su -
git clone https://github.com/MxNxPx/gitlab-cicd-demo gitlab-cicd-demo && cd $\_
```

### setup minikube
```
minikube start --vm-driver none --cpus=4 --memory=4G --kubernetes-version v1.15.3
minikube addons enable ingress
```


## DEPLOY GITLAB

### setup namespace for gitlab in minikube
```
kubectl create ns gitlab
```

### add helm repo for gitlab
```
helm repo add gitlab https://charts.gitlab.io/
helm repo update
## (optional) gitlab helm package - download to view locally
#helm fetch gitlab/gitlab
#tar -zxvf gitlab-*.tgz
```

### using helm - install gitlab to minikube
```
MINI_IP=$(minikube ip)
helm upgrade --install gitlab gitlab/gitlab \
   --namespace gitlab \
   --timeout 600s \
   --set global.hosts.domain=$MINI_IP.nip.io \
   --set global.hosts.externalIP=$MINI_IP \
   --version 2.1.14 \
   -f values-minikube-minimum.yaml
```

### in another terminal window - make sure it all is running and ready
```
watch kubectl get po -n gitlab
#ctrl+c to exit

##when ready it will look similar to this
#NAME                                       READY   STATUS      RESTARTS   AGE
#gitlab-gitaly-0                            1/1     Running     0          8m56s
#gitlab-gitlab-exporter-645f7575b9-zkdwm    1/1     Running     0          8m56s
#gitlab-gitlab-shell-5885458d85-rmjkz       1/1     Running     0          8m57s
#gitlab-migrations.1-59b78                  0/1     Completed   1          8m56s
#gitlab-minio-8f879c754-ttvw7               1/1     Running     0          8m56s
#gitlab-minio-create-buckets.1-tsjxm        0/1     Completed   0          8m56s
#gitlab-postgresql-66d8d9574b-f8b4m         2/2     Running     0          8m57s
#gitlab-redis-7c6f9d8585-jk978              2/2     Running     0          8m56s
#gitlab-registry-54964ddfdc-zv2dt           1/1     Running     0          8m57s
#gitlab-sidekiq-all-in-1-6658c9547b-d4xlv   1/1     Running     0          8m56s
#gitlab-task-runner-7768d75c46-d257t        1/1     Running     0          8m57s
#gitlab-unicorn-557d575bc9-68tnm            2/2     Running     1          8m56s
```


## MINIKUBE AND GITLAB CONFIG

### trust gitlab registry certs for docker and minikube
```
GITLABREGISTRY=$(kubectl get -n gitlab ing gitlab-registry -o jsonpath="{.spec.rules[0].host}" && echo) && echo $GITLABREGISTRY
echo -n | openssl s_client -connect ${GITLABREGISTRY}:443 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ${GITLABREGISTRY}.crt
mkdir -v /usr/local/share/ca-certificates/minikube/
cp -pv ${GITLABREGISTRY}.crt /usr/local/share/ca-certificates/minikube/
update-ca-certificates
```

### stop minikube and docker
```
minikube stop
systemctl stop docker
docker ps 
#should not see any docker containers and likely get a docker error which is desired
```

### start docker and minikube
```
systemctl start docker
minikube start --vm-driver none --cpus=4 --memory=4G --kubernetes-version v1.15.3
```

### again in another terminal window - make sure it all restarts healthy
```
watch kubectl get po --all-namespaces
#ctrl+c to exit
#if any pods are not "Running" or "Completed" (such as "RunContainerError" or "CrashLoopBackOff") after 5-10 mins, run this command
kubectl -n gitlab get pods | egrep -v "NAME|Running|Completed" | awk '{print $1}' | xargs kubectl -n gitlab delete pod
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
gitlab/gitlab-runner:v12.5.0
```

### create certs dir under docker volume and pull down gitlab ca cert from k8s into certs dir for docker container
```
mkdir /srv/gitlab-runner/config/certs && \
kubectl get secrets/gitlab-wildcard-tls-ca -n gitlab -o "jsonpath={.data['cfssl_ca']}" | base64 --decode > /tmp/ca.crt && \
mv /tmp/ca.crt /srv/gitlab-runner/config/certs
GITURL=$(echo -n "https://" ; kubectl -n gitlab get ingress gitlab-unicorn -ojsonpath='{.spec.rules[0].host}' ; echo) && echo $GITURL
```

### register the docker gitlab runner
```
docker run -v /srv/gitlab-runner/config:/etc/gitlab-runner --rm -t -i gitlab/gitlab-runner:v12.5.0 register \
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


### get and set vars for gitlab url - user root and root password for UI
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

### login to UI using root and GITROOTPWD create gitlab-cicd-demo project
```
echo ${GITURL}
google-chrome ${GITURL} &
#if using multipass, copy this URL and put it in your browser

#Under Create New Project > Import Project > Repo by URL
#Paste this repo URL: https://github.com/MxNxPx/gitlab-cicd-demo.git
#Project name: gitlab-cicd-demo
#Project slug: gitlab-cicd-demo
#Visibility level: Public
#Click "Create project"
```

### using values from above - create gitlab cicd variables needed for deploy
```
#Under Project (gitlab-cicd-demo) > Settings > CICD > Variables > Expand
#Variable: MINIKUBE_APISERVER $MINIKUBE_APISERVER
#Variable: MINIKUBE_USER_TOKEN $MINIKUBE_USER_TOKEN
#File: MINIKUBE_CA $MINIKUBE_CA
#Click "Save variables"
```


## KICK OFF A PIPELINE

### setup terminal window to watch kubernetes for deployment
```
watch kubectl get po -n default
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

### watch the pipeline run
```
#In the pipeline tab an entry should appear in running state
#Click into that and see all the steps it plans to run
#Click into each step to watch progress
#Before the deploy step runs, pop over to the terminal with the "watch" command running to see it deploy
```

### see your hello world page
```
HELLO_URL=$(echo "http://$(minikube ip):30800") && echo $HELLO_URL
google-chrome ${HELLO_URL} &
#if using multipass, copy this URL and put it in your browser
```

### change something and watch pipeline run again
```
#Under gitlab-cicd-demo project (left nav) > Repository > Files
#Click the Dockerfile file
#Click Edit
#Change the base image from
#"FROM python:3.6-alpine"
#to
#"FROM python:3.4.3"
#Scroll to bottom and click "Commit Changes"
```



## ADDITIONAL INFO

### Useful links
https://docs.gitlab.com/ee/administration/troubleshooting/kubernetes_cheat_sheet.html#installation-of-minimal-gitlab-config-via-minukube-on-macos  
https://docs.gitlab.com/ee/ci/introduction/  
https://github.com/gitlabhq/gitlabhq/blob/master/doc/ci/quick_start/README.md  
https://sanderknape.com/2019/02/automated-deployments-kubernetes-gitlab/  
https://nvie.com/posts/a-successful-git-branching-model/  



### ALL DONE - cleanup steps
```
#if using multipass follow these steps
multipass list
multipass delete ubuntu-multipass
multipass purge
multipass list  #should only show the primary instance to confirm it wiped properly

#if not using multipass follow these steps
helm delete -n gitlab gitlab
minikube delete
docker rm --force gitlab-runner
rm -rfv /srv/gitlab-runner/config/*
#BEWARE! command below will wipe ALL local docker containers and data
#docker system prune -a
```
