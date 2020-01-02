# using multipass

## install multipass then run the following from a terminal
```
multipass launch 18.04 --name ubuntu-multipass --cpus 3 --mem 8G --disk 18G

multipass list

multipass shell ubuntu-multipass
```

## launch a shell into the multipass instance and install the prereqs
```
## install curl, jq, and docker
{
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common jq
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
sudo apt install -y docker-ce
#sudo systemctl status docker
sudo usermod -aG docker ${USER}
id -nG
sudo usermod -aG docker ${USER}
newgrp docker
id -nG
docker ps
}

## install helm3
{
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
}

## install kubectl
{
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo touch /etc/apt/sources.list.d/kubernetes.list 
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl
}

## install minikube
{
wget https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube-linux-amd64
sudo mv minikube-linux-amd64 /usr/local/bin/minikube
}
```

## proceed with the steps in the [readme](README.md)
