#!/bin/bash -xe

source /etc/environment
source /root/config.cfg

mkdir -p /apps/soca/$SOCA_CONFIGURATION

SERVER_IP=$(hostname -I)
SERVER_HOSTNAME=$(hostname)
SERVER_HOSTNAME_ALT=$(echo $SERVER_HOSTNAME | cut -d. -f1)
echo $SERVER_IP $SERVER_HOSTNAME $SERVER_HOSTNAME_ALT >> /etc/hosts

if [[ $SOCA_BASE_OS == "rhel7" ]]
then
    yum install -y $(echo ${SYSTEM_PKGS[*]} ${SCHEDULER_PKGS[*]}) --enablerepo rhui-REGION-rhel-server-optional
else
    yum install -y $(echo ${SYSTEM_PKGS[*]} ${SCHEDULER_PKGS[*]})
fi

yum install -y $(echo ${OPENLDAP_SERVER_PKGS[*]} ${SSSD_PKGS[*]})

# Mount EFS
resize2fs /dev/nvme1n1
#mkdir /apps
mkdir -p /data/home
echo "/dev/nvme1n1 /apps ext4 defaults 0 0" >> /etc/fstab
mount -a
echo "/data *(rw,sync,no_subtree_check,no_root_squash,insecure)" >> /etc/exports
echo "/apps *(rw,sync,no_subtree_check,no_root_squash,insecure)" >> /etc/exports
exportfs -rv
systemctl start nfs
systemctl enable nfs

# Install Python if needed
PYTHON_INSTALLED_VERS=$(/apps/soca/$SOCA_CONFIGURATION/python/latest/bin/python3 --version | awk {'print $NF'})
if [[ "$PYTHON_INSTALLED_VERS" != "$PYTHON_VERSION" ]]
then
    echo "Python not detected, installing"
    mkdir -p /apps/soca/$SOCA_CONFIGURATION/python/installer
    cd /apps/soca/$SOCA_CONFIGURATION/python/installer
    wget $PYTHON_URL
    if [[ $(md5sum $PYTHON_TGZ | awk '{print $1}') != $PYTHON_HASH ]];  then
        echo -e "FATAL ERROR: Checksum for Python failed. File may be compromised." > /etc/motd
        exit 1
    fi
    tar xvf $PYTHON_TGZ
    cd Python-$PYTHON_VERSION
    ./configure LDFLAGS="-L/usr/lib64/openssl" CPPFLAGS="-I/usr/include/openssl" -enable-loadable-sqlite-extensions --prefix=/apps/soca/$SOCA_CONFIGURATION/python/$PYTHON_VERSION
    make
    make install
    ln -sf /apps/soca/$SOCA_CONFIGURATION/python/$PYTHON_VERSION /apps/soca/$SOCA_CONFIGURATION/python/latest
else
    echo "Python already installed and at correct version."
fi

# Install OpenPBS if needed
cd ~
OPENPBS_INSTALLED_VERS=$(/opt/pbs/bin/qstat --version | awk {'print $NF'})
if [[ "$OPENPBS_INSTALLED_VERS" != "$OPENPBS_VERSION" ]]
then
    echo "OpenPBS Not Detected, Installing OpenPBS ..."
    cd ~
    wget $OPENPBS_URL
    if [[ $(md5sum $OPENPBS_TGZ | awk '{print $1}') != $OPENPBS_HASH ]];  then
        echo -e "FATAL ERROR: Checksum for OpenPBS failed. File may be compromised." > /etc/motd
        exit 1
    fi
    tar zxvf $OPENPBS_TGZ
    cd openpbs-$OPENPBS_VERSION
    ./autogen.sh
    ./configure --prefix=/opt/pbs
    make -j6
    make install -j6
    /opt/pbs/libexec/pbs_postinstall
    chmod 4755 /opt/pbs/sbin/pbs_iff /opt/pbs/sbin/pbs_rcp
else
    echo "OpenPBS already installed, and at correct version."
    echo "PBS_SERVER=$SERVER_HOSTNAME_ALT
PBS_START_SERVER=1
PBS_START_SCHED=1
PBS_START_COMM=1
PBS_START_MOM=0
PBS_EXEC=/opt/pbs
PBS_HOME=/var/spool/pbs
PBS_CORE_LIMIT=unlimited
PBS_SCP=/usr/bin/scp
" > /etc/pbs.conf
    echo "$clienthost $SERVER_HOSTNAME_ALT" > /var/spool/pbs/mom_priv/config
fi


# Edit path with new scheduler/python locations
echo "export PATH=\"/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/pbs/bin:/opt/pbs/sbin:/opt/pbs/bin:/apps/soca/$SOCA_CONFIGURATION/python/latest/bin\"" >> /etc/environment

# Default AWS Resources
cat <<EOF >>/var/spool/pbs/server_priv/resourcedef
anonymous_metrics type=string
asg_spotfleet_id type=string
availability_zone type=string
base_os type=string
compute_node type=string flag=h
efa_support type=string
error_message type=string
force_ri type=string
fsx_lustre type=string
fsx_lustre_deployment_type type=string
fsx_lustre_per_unit_throughput type=string
fsx_lustre_size type=string
ht_support type=string
instance_ami type=string
instance_id type=string
instance_type type=string
instance_type_used type=string
keep_ebs type=string
placement_group type=string
root_size type=string
scratch_iops type=string
scratch_size type=string
spot_allocation_count type=string
spot_allocation_strategy type=string
spot_price type=string
stack_id type=string
subnet_id type=string
system_metrics type=string
EOF

systemctl enable pbs
systemctl start pbs

# Default Server config
/opt/pbs/bin/qmgr -c "create node $SERVER_HOSTNAME_ALT"
/opt/pbs/bin/qmgr -c "set node $SERVER_HOSTNAME_ALT queue = workq"
/opt/pbs/bin/qmgr -c "set server flatuid=true"
/opt/pbs/bin/qmgr -c "set server job_history_enable=1"
/opt/pbs/bin/qmgr -c "set server job_history_duration = 01:00:00"
/opt/pbs/bin/qmgr -c "set server scheduler_iteration = 30"
/opt/pbs/bin/qmgr -c "set server max_concurrent_provision = 5000"

# Default Queue Config
/opt/pbs/bin/qmgr -c "create queue low"
/opt/pbs/bin/qmgr -c "set queue low queue_type = Execution"
/opt/pbs/bin/qmgr -c "set queue low started = True"
/opt/pbs/bin/qmgr -c "set queue low enabled = True"
/opt/pbs/bin/qmgr -c "set queue low default_chunk.compute_node=tbd"
/opt/pbs/bin/qmgr -c "create queue normal"
/opt/pbs/bin/qmgr -c "set queue normal queue_type = Execution"
/opt/pbs/bin/qmgr -c "set queue normal started = True"
/opt/pbs/bin/qmgr -c "set queue normal enabled = True"
/opt/pbs/bin/qmgr -c "set queue normal default_chunk.compute_node=tbd"
/opt/pbs/bin/qmgr -c "create queue high"
/opt/pbs/bin/qmgr -c "set queue high queue_type = Execution"
/opt/pbs/bin/qmgr -c "set queue high started = True"
/opt/pbs/bin/qmgr -c "set queue high enabled = True"
/opt/pbs/bin/qmgr -c "set queue high default_chunk.compute_node=tbd"
/opt/pbs/bin/qmgr -c "create queue desktop"
/opt/pbs/bin/qmgr -c "set queue desktop queue_type = Execution"
/opt/pbs/bin/qmgr -c "set queue desktop started = True"
/opt/pbs/bin/qmgr -c "set queue desktop enabled = True"
/opt/pbs/bin/qmgr -c "set queue desktop default_chunk.compute_node=tbd"
/opt/pbs/bin/qmgr -c "create queue test"
/opt/pbs/bin/qmgr -c "set queue test queue_type = Execution"
/opt/pbs/bin/qmgr -c "set queue test started = True"
/opt/pbs/bin/qmgr -c "set queue test enabled = True"
/opt/pbs/bin/qmgr -c "set queue test default_chunk.compute_node=tbd"
/opt/pbs/bin/qmgr -c "create queue alwayson"
/opt/pbs/bin/qmgr -c "set queue alwayson queue_type = Execution"
/opt/pbs/bin/qmgr -c "set queue alwayson started = True"
/opt/pbs/bin/qmgr -c "set queue alwayson enabled = True"
/opt/pbs/bin/qmgr -c "set server default_queue = normal"

# Add compute_node to list of required resource
sed -i 's/resources: "ncpus, mem, arch, host, vnode, aoe, eoe"/resources: "ncpus, mem, arch, host, vnode, aoe, eoe, compute_node"/g' /var/spool/pbs/sched_priv/sched_config

# Disable SELINUX
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

# Disable StrictHostKeyChecking
echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
echo "UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config

# Install Python required libraries
# Source environment to reload path for Python3
#/apps/soca/$SOCA_CONFIGURATION/python/$PYTHON_VERSION/bin/pip3 install -r /root/requirements.txt
/apps/soca/$SOCA_CONFIGURATION/python/$PYTHON_VERSION/bin/pip3 install -i https://opentuna.cn/pypi/web/simple -r /root/requirements.txt

# Configure Chrony
yum remove -y ntp
mv /etc/chrony.conf  /etc/chrony.conf.original
echo -e """
# use the local instance NTP service, if available
server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4
# Use public servers from the pool.ntp.org project.
# Please consider joining the pool (http://www.pool.ntp.org/join.html).
# !!! [BEGIN] SOCA REQUIREMENT
# You will need to open UDP egress traffic on your security group if you want to enable public pool
#pool 2.amazon.pool.ntp.org iburst
# !!! [END] SOCA REQUIREMENT
# Record the rate at which the system clock gains/losses time.
driftfile /var/lib/chrony/drift
# Allow the system clock to be stepped in the first three updates
# if its offset is larger than 1 second.
makestep 1.0 3
# Specify file containing keys for NTP authentication.
keyfile /etc/chrony.keys
# Specify directory for log files.
logdir /var/log/chrony
# save data between restarts for fast re-load
dumponexit
dumpdir /var/run/chrony
""" > /etc/chrony.conf
systemctl enable chronyd

# Disable ulimit
echo -e  "
* hard memlock unlimited
* soft memlock unlimited
" >> /etc/security/limits.conf

# Reboot to ensure SELINUX is disabled
# Note: Upon reboot, SchedulerPostReboot.sh script will be executed and will finalize scheduler configuration
reboot
