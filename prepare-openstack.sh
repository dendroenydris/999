#!/bin/bash

# Step 7: Create security group "open-all"
echo "Creating security group 'open-all'..."
openstack security group create open-all --description "Allow all traffic"

# Step 8: Add security group rules
echo "Adding security group rules..."
# Allow all incoming TCP traffic
openstack security group rule create --protocol tcp --ingress open-all
# Allow all incoming UDP traffic
openstack security group rule create --protocol udp --ingress open-all
# Allow all incoming ICMP traffic
openstack security group rule create --protocol icmp --ingress open-all
# Allow all outgoing traffic
openstack security group rule create --protocol tcp --egress open-all
openstack security group rule create --protocol udp --egress open-all
openstack security group rule create --protocol icmp --egress open-all

# Step 9: Create and import keypair
echo "Creating new keypair..."
# Generate key if it doesn't exist
if [ ! -f ~/.ssh/openstack_key ]; then
    ssh-keygen -t rsa -b 2048 -f ~/.ssh/openstack_key -N ""
    chmod 400 ~/.ssh/openstack_key
fi
# Import the public key to OpenStack
openstack keypair create --public-key ~/.ssh/openstack_key.pub openstack-key

# Step 10: Create VM instance
echo "Creating VM instance..."
openstack server create \
    --image ubuntu-16.04 \
    --flavor m1.medium \
    --network admin-net \
    --security-group open-all \
    --key-name openstack-key \
    ubuntu-vm

# Wait for VM to be active
echo "Waiting for VM to become active..."
while [ "$(openstack server show ubuntu-vm -f value -c status)" != "ACTIVE" ]; do
    echo -n "."
    sleep 2
done
echo "VM is active."

# Step 11: Assign floating IP
echo "Creating and assigning floating IP..."
FLOATING_IP=$(openstack floating ip create external -f value -c floating_ip_address)
openstack server add floating ip ubuntu-vm $FLOATING_IP
echo "Floating IP $FLOATING_IP assigned to ubuntu-vm"

