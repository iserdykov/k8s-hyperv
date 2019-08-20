#!/bin/bash

# CALICO + DOCKER
# 5752 MB, 2606 MB, 2636 MB, CPU 23%, 100 Kbps
# load average: 1.28, 0.80, 0.72
# load average: 1.05, 0.61, 0.31
# load average: 0.22, 0.21, 0.20
export PODPLUG='echo https://docs.projectcalico.org/v3.7/manifests/calico.yaml'
export PODNET=192.168.0.0/16

# FLANNEL + DOCKER
# 5238 MB, 2480 MB, 2454 MB, CPU 16%, 0 Kbps
# load average: 0.15, 0.34, 0.31
# load average: 0.03, 0.06, 0.02
# load average: 0.04, 0.09, 0.07
export PODPLUG='echo https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml'
export PODNET=10.244.0.0/16


# WEAVE + DOCKER
# 5614 MB, 3028 MB, 3038 MB, CPU 20%, 100 Kbps
# load average: 0.14, 0.36, 0.24
# load average: 0.08, 0.05, 0.03
# load average: 0.03, 0.11, 0.08
export PODPLUG='echo https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d "\n")'
export PODNET=10.32.0.0/12


sudo kubeadm init --pod-network-cidr=$PODNET && \
mkdir -p $HOME/.kube && \
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && \
sudo chown $(id -u):$(id -g) $HOME/.kube/config && \
kubectl apply -f $(eval $PODPLUG) && \
sudo kubeadm token create --print-join-command


kubectl get events --all-namespaces && \
kubectl get pods --all-namespaces && \
kubectl get nodes

#---------------------------------------------------

hyperctl get events --all-namespaces
hyperctl get pods --all-namespaces
hyperctl get nodes

