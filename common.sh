#!/bin/bash
set -e


sudo cat << EOF > /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.73.100 master.calvarado04.com
192.168.73.200 worker0.calvarado04.com
192.168.73.201 worker1.calvarado04.com
192.168.73.202 worker2.calvarado04.com
EOF

cat << EOF > /etc/yum.repos.d/docker-ce.repo
[docker-ce-stable]
name=Docker CE Stable - x86_64
baseurl=https://download.docker.com/linux/centos/8/x86_64/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/centos/gpg
exclude=docker*
EOF

cat << EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg \
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF

mkdir -p /etc/docker
cat <<EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

cat << EOF > /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

yum install -y device-mapper-persistent-data lvm2 \
    kubeadm-1.22.4 kubelet-1.22.4 kubectl-1.22.4 docker-ce-20.10.11-3.el8.x86_64 nfs-utils kernel-devel kernel-headers gcc cloud-utils-growpart \
    --disableexcludes=kubernetes,docker-ce-stable

growpart /dev/sda 1
xfs_growfs /dev/sda1

systemctl daemon-reload

systemctl restart docker

systemctl enable docker.service
systemctl enable --now kubelet

setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

sed -i 's/FirewallBackend=nftables/FirewallBackend=iptables/g' /etc/firewalld/firewalld.conf

sysctl --system

swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

modprobe br_netfilter

systemctl enable firewalld
systemctl start firewalld

firewall-cmd --add-masquerade --permanent
firewall-cmd --reload


firewall-cmd --zone=public --permanent --add-port={6443,2379,2380,10250,10251,10252}/tcp

#VM Nodes
firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=ipv4 source address=192.168.73.0/24 accept'

#Docker
firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=ipv4 source address=172.17.0.0/16 accept'

#K8s Services
firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=ipv4 source address=10.96.0.0/12 accept'

#K8s Pods
firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=ipv4 source address=10.244.0.0/16 accept'

firewall-cmd --zone=public --permanent --add-port={179,10250,30000-32767}/tcp

firewall-cmd --reload

