#!/bin/bash

echo step 1 !!!!!!Reset kube!!!!!!!!
sshpass -e ssh -t spark@10.129.6.15 "sudo kubeadm reset"

echo ....reset done for 15.....

sshpass -e ssh -t spark@10.129.6.14 "sudo kubeadm reset"

echo ....reset done for 14.....

sshpass -e ssh -t spark@10.129.6.16 "sudo kubeadm reset"

echo ....reset done for 16.....

sshpass -e ssh -t spark@10.129.6.17 "sudo kubeadm reset"

echo ....reset done for 17.....

echo step 2 !!!!!! swapoff and internet connection!!!!!!
sshpass -e ssh -t spark@10.129.6.15 "sudo swapoff -v -a && curl --location-trusted -u 203050088:39e484b11ed5ea4a866b29c6384a970f "https://internet-sso.iitb.ac.in/login.php" > /dev/null"


echo ....step 2 done for 15....

sshpass -e ssh -t spark@10.129.6.14 "sudo swapoff -v -a && curl --location-trusted -u 203050088:39e484b11ed5ea4a866b29c6384a970f "https://internet-sso.iitb.ac.in/login.php" > /dev/null"

echo ....step 2 done for 14....

sshpass -e ssh -t spark@10.129.6.16 "sudo swapoff -v -a && curl --location-trusted -u 203050088:39e484b11ed5ea4a866b29c6384a970f "https://internet-sso.iitb.ac.in/login.php" > /dev/null"

echo ....step 2 done for 16....

sshpass -e ssh -t spark@10.129.6.15 "sudo swapoff -v -a && curl --location-trusted -u 203050088:39e484b11ed5ea4a866b29c6384a970f "https://internet-sso.iitb.ac.in/login.php" > /dev/null"

echo ....step 2 done for 17....

echo !!!!!!Step 3 Master setup!!!!!!
sshpass -e ssh -t spark@10.129.6.15 "./master_setup/setup_master.sh"

sshpass -e ssh -t spark@10.129.6.15 "kubeadm token create --print-join-command" | tee join.sh

echo "$(tail -n +2 join.sh)" > join.sh

sed -i 's/$/ --ignore-preflight-errors=ALL/g' join.sh

sed -i 's/^/"/;s/$/"/' join.sh
sed -i 's/kubeadm/sudo kubeadm/g' join.sh

echo .......joining 1st Node 14......

sed -i 's/^/sshpass \-e ssh \-t spark\@10\.129\.6\.14 /g' join.sh

./join.sh

echo .......joining 1st Node 16......

sed -i 's/sshpass \-e ssh \-t spark\@10\.129\.6\.14/sshpass \-e ssh \-t spark\@10\.129\.6\.16/g' join.sh

./join.sh

echo .......joining 1st Node 17......

sed -i 's/sshpass \-e ssh \-t spark\@10\.129\.6\.16/sshpass \-e ssh \-t spark\@10\.129\.6\.17/g' join.sh

./join.sh


YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "\n${YELLOW}Convert YAML into service:${NC}"

sshpass -e ssh -t spark@10.129.6.15 "kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml"

echo -e "\n${YELLOW}Getting services:${NC}"
sshpass -e ssh -t spark@10.129.6.15 "kubectl -n kube-system get services"

echo -e "\n${YELLOW}Editing kubernetes-dashboard service:${NC}"
sshpass -e ssh -t spark@10.129.6.15 "kubectl -n kube-system patch svc kubernetes-dashboard -p '{\"spec\":{\"type\": \"NodePort\"}}'"

echo -e "\n${YELLOW}Change port:${NC}"
sshpass -e ssh -t spark@10.129.6.15 "lsof -i tcp:31975"

echo -e "\n${YELLOW}Setting up dashboard:${NC}"
sshpass -e ssh -t spark@10.129.6.15 "kubectl create serviceaccount dashboard-admin-sa && kubectl create clusterrolebinding dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=default:dashboard-admin-sa"

echo -e "\n${YELLOW}!!!!!!Now run getsecrets and save the token for dashboard!!!!!!!!${NC}"











