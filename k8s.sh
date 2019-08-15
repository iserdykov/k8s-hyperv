# **** WORK IN PROGRESS ****
# this file is a scratchpad - it is not supposed to be run directly

sudo tail -f /var/log/syslog
. log

# CALICO
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
sudo kubeadm join ...

# kubectl get nodes
# kubectl get pods --all-namespaces
kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml



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