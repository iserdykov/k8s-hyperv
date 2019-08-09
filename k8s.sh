

# **** WORK IN PROGRESS ****

# this file is a scratch-pad - it is not supposed to be run directly


# when using Bash on Cygwin or Mac, setup the local env:
cd ~
mkdir .kube
scp ${user}@master:/etc/kubernetes/admin.conf ~/.kube/config


# setup the k8s cluseter (Calico)
kubeadm init --pod-network-cidr=192.168.0.0/16
kubeadm token create --print-join-command
kubeadm join ...

# auth token for dashboard:
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep k8s-admin | awk '{print $1}')

kubectl proxy



# Install a Pod Network (Calico)
kubectl apply -f https://docs.projectcalico.org/v3.5/getting-started/kubernetes/installation/hosted/etcd.yaml
kubectl apply -f https://docs.projectcalico.org/v3.5/getting-started/kubernetes/installation/hosted/calico.yaml

# Install the K8s dashboard
kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/kubernetes-dashboard.yaml
# Create an admin account called k8s-admin
kubectl --namespace kube-system create serviceaccount k8s-admin
kubectl create clusterrolebinding k8s-admin --serviceaccount=kube-system:k8s-admin --clusterrole=cluster-admin

