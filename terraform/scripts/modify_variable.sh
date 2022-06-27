#!/bin/bash

vm_floating_ip_cidr="193.190.80.0/25"
vsc_floating_ip_cidr="172.24.48.0/20"

openstack catalog list &>/dev/null
[ $? -ne 0 ] && echo "Unable to list openstack catalog. Exiting.." 1>&2 && exit 1

vm_network_id="$(openstack network list -f value -c ID -c Name|grep '_vm'|cut -d ' ' -f1)" && \
	echo "VM network id: $vm_network_id."
vm_subnet_id="$(openstack network list -c Subnets -c Name|grep '_vm'|awk '{print $4}')" && \
	echo "VM subnet id: $vm_subnet_id."
nfs_network_id="$(openstack network list -f value -c ID -c Name|grep '_nfs'|cut -d ' ' -f1)" && \
	echo "NFS network id: $nfs_network_id."
nfs_subnet_id="$(openstack network list -c Subnets -c Name|grep '_nfs'|awk '{print $4}')" && \
	echo "NFS subnet id: $nfs_subnet_id."
vsc_network_id="$(openstack network list -f value -c ID -c Name|grep '_vsc'|cut -d ' ' -f1)" && \
	echo "VSC network id: $vsc_network_id."
vsc_subnet_id="$(openstack network list -c Subnets -c Name|grep '_vsc'|awk '{print $4}')" && \
	echo "VSC subnet id: $vsc_subnet_id."

access_key="$(openstack key list -c Name -f value|head -1)"
[ -z "$access_key" ] && echo "Unable to find ssh access key. Exiting.." 1>&2 && exit 1
echo "Using first ssh access key \"$access_key\"."

ssh_forwarded_port1="$(shuf -i 51001-59999 -n 1)"
ssh_forwarded_port2="$(shuf -i 51001-59999 -n 1)"
ssh_forwarded_port3="$(shuf -i 51001-59999 -n 1)"
ssh_forwarded_port4="$(shuf -i 51001-59999 -n 1)"
http_forwarded_port="$(shuf -i 51001-59999 -n 1)"
echo "Using ssh forwarded ports: $ssh_forwarded_port1 $ssh_forwarded_port2 $ssh_forwarded_port3 $ssh_forwarded_port4."
echo "Using http forwarded port: $http_forwarded_port."

while read line
do
	ip="$(echo "$line"|awk '{print $2}')"
	ip_id="$(echo "$line"|awk '{print $1}')"
	python3 -c "import ipaddress; ip = ipaddress.ip_address('$(echo "$ip")') in ipaddress.ip_network('$(echo "$vm_floating_ip_cidr")'); print (ip);"|grep "True" &>/dev/null && export floating_ip_id="$ip_id" && export floating_ip="$ip" && break
done < <(openstack floating ip list -f value -c "Floating IP Address" -c ID -c "Port"|grep None)
[ -z "$floating_ip_id" ] && echo "Unable to find floating ip address. Exiting.." 1>&2 && exit 1
echo "Using floating ip id: $floating_ip_id. (floating ip: $floating_ip)"
while read line
do
        ip="$(echo "$line"|awk '{print $1}')"
	python3 -c "import ipaddress; ip = ipaddress.ip_address('$(echo "$ip")') in ipaddress.ip_network('$(echo "$vsc_floating_ip_cidr")'); print (ip);"|grep "True" &>/dev/null && export vsc_floating_ip="$ip" && break
done < <(openstack floating ip list -f value -c "Floating IP Address" -c "Port"|grep None)
[ -z "$vsc_floating_ip" ] && echo "Unable to find VSC floating ip address. Exiting.." 1>&2 && exit 1
echo "Using VSC floating ip: $vsc_floating_ip."


sed -i "s/_VM_NETWORK_ID_/$vm_network_id/g" ../environment/main.tf
sed -i "s/_VM_SUBNET_ID_/$vm_subnet_id/g" ../environment/main.tf
sed -i "s/_NFS_NETWORK_ID_/$nfs_network_id/g" ../environment/main.tf
sed -i "s/_NFS_SUBNET_ID_/$nfs_subnet_id/g" ../environment/main.tf
sed -i "s/_VSC_NETWORK_ID_/$vsc_network_id/g" ../environment/main.tf
sed -i "s/_VSC_SUBNET_ID_/$vsc_subnet_id/g" ../environment/main.tf
sed -i "s/_ACCESS_KEY_/$access_key/g" ../environment/main.tf
sed -i "s/_SSH_FORWARDED_PORT1_/$ssh_forwarded_port1/g" ../environment/main.tf
sed -i "s/_SSH_FORWARDED_PORT2_/$ssh_forwarded_port2/g" ../environment/main.tf
sed -i "s/_SSH_FORWARDED_PORT3_/$ssh_forwarded_port3/g" ../environment/main.tf
sed -i "s/_SSH_FORWARDED_PORT4_/$ssh_forwarded_port4/g" ../environment/main.tf
sed -i "s/_HTTP_FORWARDED_PORT_/$http_forwarded_port/g" ../environment/main.tf
sed -i "s/_FLOATING_IP_ID_/$floating_ip_id/g" ../environment/main.tf
sed -i "s/_VSC_FLOATING_IP_/$vsc_floating_ip/g" ../environment/main.tf
