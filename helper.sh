#!/bin/bash

# Helper script for managing installations and configurations

# Print help menu
function help_menu() {
    cat << EOF
Usage: $0 [function]

Available functions:
  sudolessUser          - Set passwordless sudo for the current user.
  checkBasics           - Update and install basic tools (wget, git, curl).
  checkDocker           - Check and install Docker if not present.
  checkHelm             - Check and install Helm if not present.
  checkKubectl          - Check and install kubectl if not present.
  installGo             - Check and install Go programming language.
  installKpt            - Check and install Kpt.
  installMongo          - Check and install MongoDB.
  installKind           - Check and install Kubernetes Kind.
  uninstallDocker       - Completely remove Docker and related files.
  installDockerViaScript - Install Docker using Docker's official script.
  setupKubeHome         - Set up Kubernetes configuration in home directory.
  kubeComplete          - Enable kubectl command completion.
  removeNonRunningPods  - Remove all non-running pods.
  deleteNamespace       - Force delete a Kubernetes namespace.
  deleteAllFromNamespace - Delete all resources from a namespace.
  forceDeleteNamespace  - Force delete a namespace by removing finalizers.
  listContainerdImages  - List images in containerd.
  curlpod               - Run a temporary pod with curl.
  increaseInotifyLimits - Increase inotify limits.
  help                  - Display this help menu.

Example:
  $0 checkDocker
EOF
}

# Set passwordless sudo for the user
function sudolessUser() {
    if sudo grep -qE "^\s*${USER}\s+ALL=(ALL:ALL)\s+NOPASSWD:" /etc/sudoers; then
        echo "Passwordless sudo is already set for the user."
    else
        echo "Setting passwordless sudo for the user..."
        echo "${USER} ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
        echo "Passwordless sudo privileges have been set for the user."
    fi
}

# Update and install basic tools
function checkBasics() {
    sudo apt update
    sudo apt install -y wget git curl
}

# Install or verify Docker
function checkDocker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Installing it..."
        sudo apt-get update -y
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update -y
        sudo apt-get install docker-ce docker-ce-cli containerd.io -y
        sudo usermod -aG docker $USER
        newgrp docker
    else
        sudo usermod -aG docker $USER
        newgrp docker
        echo "Docker is installed."
    fi
}

# Install or verify Helm
function checkHelm() {
    if ! command -v helm &> /dev/null; then
        echo "Helm is not installed. Installing it..."
        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
        chmod 700 ./get_helm.sh
        ./get_helm.sh
        rm ./get_helm.sh
    else
        echo "Helm is installed."
    fi
}

# Install or verify kubectl
function checkKubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl is not installed. Installing it..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        echo "source <(kubectl completion bash)" >> ~/.bashrc
        echo "alias k=kubectl" >> ~/.bashrc
        echo "complete -o default -F __start_kubectl k" >> ~/.bashrc
        source ~/.bashrc
    else
        echo "kubectl is installed."
    fi
}

# Install or verify Go programming language
function installGo() {
    if ! command -v go &> /dev/null; then
        echo "Go is not installed. Installing it..."
        wget https://go.dev/dl/go1.24.5.linux-amd64.tar.gz
        sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.24.5.linux-amd64.tar.gz
        rm go1.24.5.linux-amd64.tar.gz
        echo 'export GOPATH=$HOME/go' >> ~/.bashrc
        echo 'export GOROOT=/usr/local/go' >> ~/.bashrc
        echo 'export PATH=$PATH:$GOPATH/bin:$GOROOT/bin' >> ~/.bashrc
        source ~/.bashrc
    else
        echo "Go is installed."
    fi
}

function installKpt() {
    if ! command -v kpt &> /dev/null; then
        echo "Kpt is not installed. Installing it..."
        go install -v github.com/kptdev/kpt@main
    else
        echo "Kpt is installed."
    fi
}

# Install or verify MongoDB
function installMongo() {
    if ! command -v mongo &> /dev/null; then
        echo "Mongo is not installed. Installing it..."
        wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo gpg --dearmor --output /etc/apt/trusted.gpg.d/mongodb.gpg
        echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb.list
        sudo apt update
        sudo apt install -y mongodb-org
        sudo systemctl start mongod
        sudo systemctl enable mongod
    else
        echo "Mongo is installed."
    fi
}

# Install or verify Kubernetes Kind
function installKind() {
    if ! command -v kind &> /dev/null; then
        echo "Kind is not installed. Installing it..."
        GET_VER=$(curl -L -s https://github.com/kubernetes-sigs/kind/releases/latest | grep '^\s*v' | sed 's/ //g')
        sudo curl -Lo /usr/local/kind https://kind.sigs.k8s.io/dl/$GET_VER/kind-linux-amd64
        sudo install -o root -g root -m 0755 /usr/local/kind /usr/local/bin/kind
    else
        echo "Kind is installed."
    fi
}

# Completely uninstall Docker
function uninstallDocker() {
    sudo apt-get purge -y docker-engine docker docker.io docker-ce docker-ce-cli docker-compose-plugin
    sudo apt-get autoremove -y --purge docker-engine docker docker.io docker-ce docker-compose-plugin
    sudo rm -rf /var/lib/docker /etc/docker
    sudo rm /etc/apparmor.d/docker
    sudo groupdel docker
    sudo rm -rf /var/run/docker.sock
    sudo rm -rf /var/lib/containerd
    sudo rm -r ~/.docker
}

# Install Docker using the official script
function installDockerViaScript() {
    wget -qO- https://get.docker.com/ | sh
    sudo usermod -aG docker $USER
    newgrp docker
}

# Kubernetes cleanup and management tasks
function kubehome() {
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
}

function kubeComplete() {
    echo 'source /etc/bash_completion' >>~/.bashrc
    echo 'source <(kubectl completion bash)' >>~/.bashrc
    echo 'alias k=kubectl' >>~/.bashrc
    echo 'complete -o default -F __start_kubectl k' >>~/.bashrc
    source ~/.bashrc
}

function removeNonRunningPods() {
    kubectl get po -A | grep -v Running | awk '{print "kubectl -n " $1 " delete pod " $2}' | sh
}

function deleteNamespace() {
    kubectl delete ns $1 --force --grace-period=0
}

function deleteAllFromNamespace() {
    kubectl delete all --all -n $1 --force --grace-period=0
}

function forceDeleteNamespace() {
    kubectl get namespace "$1" -o json \
      | tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/" \
      | kubectl replace --raw /api/v1/namespaces/$1/finalize -f -
}

function listContainerdImages() {
    ctr -n k8s.io i ls -q
}

function curlpod() {
  if [ -z "$1" ]; then
    kubectl run -it --rm --image=curlimages/curl curly -- /bin/sh
  else
    kubectl run -it --rm --image=curlimages/curl curly -n $1 -- /bin/sh
  fi
}

function increasewatchers() {
    sudo sysctl -w fs.inotify.max_user_watches=2099999999
    sudo sysctl -w fs.inotify.max_user_instances=2099999999
    sudo sysctl -w fs.inotify.max_queued_events=2099999999
}

# Main logic to handle user inputs
if [ $# -eq 0 ]; then
    help_menu
    exit 0
fi

case "$1" in
    sudolessUser) sudolessUser ;;
    checkBasics) checkBasics ;;
    checkDocker) checkDocker ;;
    checkHelm) checkHelm ;;
    checkKubectl) checkKubectl ;;
    installGo) installGo ;;
    installKpt) installKpt ;;
    installMongo) installMongo ;;
    installKind) installKind ;;
    uninstallDocker) uninstallDocker ;;
    installDockerViaScript) installDockerViaScript ;;
    setupKubeHome) setupKubeHome ;;
    kubeComplete) kubeComplete ;;
    removeNonRunningPods) removeNonRunningPods ;;
    deleteNamespace) deleteNamespace ;;
    deleteAllFromNamespace) deleteAllFromNamespace ;;
    forceDeleteNamespace) forceDeleteNamespace ;;
    listContainerdImages) listContainerdImages ;;
    curlpod) curlpod ;;
    increaseInotifyLimits) increaseInotifyLimits ;;

    help) help_menu ;;
    *) echo "Invalid option: $1"; help_menu ;;
esac
