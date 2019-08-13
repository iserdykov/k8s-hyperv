

# **** WORK IN PROGRESS ****

# this file is a scratchpad - it is not supposed to be run directly


# setup the k8s cluseter (Calico)
#sudo kubeadm init phase preflight

sudo tail -f /var/log/syslog

# CONTAINERD:
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
sudo kubeadm token create --print-join-command
sudo kubeadm join ...

# CRIO:
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket /var/run/crio/crio.sock
sudo kubeadm join ...  --cri-socket /var/run/crio/crio.sock
# [certs] apiserver serving cert is signed for DNS names [master kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 10.10.0.10]


# on master (as a regular user):
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl get nodes
kubectl get pods --all-namespaces



# when using Bash on Cygwin or Mac, setup the local env:
cd ~
mkdir .kube
scp ${user}@master:/etc/kubernetes/admin.conf ~/.kube/config

cat << EOF | sudo tee /etc/udev/rules.d/01-net-setup-link.rules
  SUBSYSTEM=="net", ACTION=="add|change", ENV{INTERFACE}=="br-*", PROGRAM="/bin/sleep 0.5"
  SUBSYSTEM=="net", ACTION=="add|change", ENV{INTERFACE}=="docker[0-9]*", PROGRAM="/bin/sleep 0.5"
EOF


# possibly cannot use Calico: https://github.com/systemd/systemd/issues/3374

# https://docs.projectcalico.org/v3.8/getting-started/kubernetes/installation/calico
# https://docs.projectcalico.org/v3.8/getting-started/kubernetes/
kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml






# auth token for dashboard:
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep k8s-admin | awk '{print $1}')
kubectl proxy
# Install the K8s dashboard
kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/kubernetes-dashboard.yaml
# Create an admin account called k8s-admin
kubectl --namespace kube-system create serviceaccount k8s-admin
kubectl create clusterrolebinding k8s-admin --serviceaccount=kube-system:k8s-admin --clusterrole=cluster-admin




