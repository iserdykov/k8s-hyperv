#!/bin/bash

# CALICO + DOCKER
# 5752 MB, 2606 MB, 2636 MB, 23% -> 6%, 100 Kbps
# load average: 1.28, 0.80, 0.72
# load average: 1.05, 0.61, 0.31
# load average: 0.22, 0.21, 0.20
export PODPLUG=https://docs.projectcalico.org/v3.7/manifests/calico.yaml
export PODNET=192.168.0.0/16

# FLANNEL + DOCKER
export PODPLUG=https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
export PODNET=10.244.0.0/16




sudo kubeadm init --pod-network-cidr=$PODNET && \
mkdir -p $HOME/.kube && \
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && \
sudo chown $(id -u):$(id -g) $HOME/.kube/config && \
kubectl apply -f $PODPLUG && \
sudo kubeadm token create --print-join-command


kubectl get events --all-namespaces && \
kubectl get pods --all-namespaces && \
kubectl get nodes


# ubuntu
cat << EOF | sudo tee /etc/systemd/system/kubelet.service.d/12-after-docker.conf
[Unit]
After=docker.service
EOF

# centos
cat << EOF | sudo tee /usr/lib/systemd/system/kubelet.service.d/12-after-docker.conf
[Unit]
After=docker.service
EOF



# ./k8s.sh init [calico|flannel|weave] node1 node2
# 1. keep trying to connect to master and determine that it had finished the cloud init
# 2. exec `sudo kubeadm init --pod-network-cidr=CIDR` on master
# 3. setup kubectl on the master
# 4. setup kubectl on local host + kube alias
# 5. x


#
#   - call kubeadm init on master (w/ proper cidr)
#   - if master is not inited yet, keeps re-trying
#

# TODO:
#   - add /etc/hosts entries into all nodes upon install
#   - have the install reboot the nodes, not shutdown
#   - create a checkfile on second boot (to signify full init)


# function initscript-file() {
#   - path: /home/$guestuser/init.sh
#     owner: $guestuser`:$guestuser
#     permissions: '0755'
#     content: |
#       sudo kubeadm init --pod-network-cidr=192.168.0.0/16
#       calico: '192.168.0.0/16'
#       weave: '10.32.0.0/12'
#       flannel: '10.244.0.0/16'
# }

# ./k8s.sh join master


  # - kubeadm init --pod-network-cidr=192.168.0.0/16
  # - mkdir -p /home/$guestuser/.kube
  # - cp -i /etc/kubernetes/admin.conf /home/$guestuser/.kube/config
  # - chown $guestuser`:$guestuser /home/$guestuser/.kube/config


# **** WORK IN PROGRESS ****
# this file is a scratchpad - it is not supposed to be run directly

#TODO kubeadm config images pull # if master

sudo tail -f /var/log/syslog
. log

# CALICO
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
#--apiserver-advertise-address=10.10.0.10
sudo kubeadm join ...

# mkdir -p $HOME/.kube
# sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
# sudo chown $(id -u):$(id -g) $HOME/.kube/config

# kubectl get nodes
# kubectl get events --all-namespaces
# kubectl get pods --all-namespaces
# kubectl get jobs --all-namespaces
# kubectl --namespace kube-system get deploy,sts,svc,configmap,secret -o yaml > system.yaml
# kubectl --namespace kube-system logs -f etcd-master

# no Calico 3.8: https://github.com/projectcalico/calico/issues/2712
# Calico 3.7 doesn't work on ubuntu 19.04 / docker
kubectl apply -f https://docs.projectcalico.org/v3.7/manifests/calico.yaml

https://raw.githubusercontent.com/coreos/flannel/master/Documentation/k8s-manifests/kube-flannel-rbac.yml



# ------ NOTES -------
systemctl stop kubelet
systemctl stop docker

systemctl start docker
systemctl restart networkd-dispatcher
systemctl start kubelet

sudo cp /var/log/syslog ./syslog3
sudo chown juraj ./syslog3
scp master:syslog3 .

WARNING:Unknown index  seen reloading interface list
Aug 14 04:30:29 master networkd-dispatcher[826]: ERROR:Unknown interface index 114 seen even after reload

libcontainer_4027_systemd_test_default.slice


# ------ OFF -------

# MASTER:
# mkdir -p $HOME/.kube
# sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
# sudo chown $(id -u):$(id -g) $HOME/.kube/config

# LOCAL:
# cd && mkdir .kube && scp master:.kube/config ~/.kube/config

# sudo kubeadm token create --print-join-command
# --cgroup-driver auto|systemd


# ------ STRATEGIES -------


unknown iface index:
  (note) was also on systemd
  x /etc/default/networkd-dispatcher  -v -v
  - get into calico pod / get log - see what creates the iface
      (replicate by recreating base pod and launching manually if pod respawn too quick)
  - networkctl list / ifconfig
  - check host time / ntpd
  - try 18.04
  - try flannel or weave
  - try multinode
  - try 16.04


- systemd:
  - pkg recomp