#!/bin/bash -xe

source /etc/environment
source /root/config.cfg

# First flush the current crontab to prevent this script to run on the next reboot
crontab -r

#add admin user
#sanitized_username="$3"
#sanitized_password="$4"

useradd -d /data/home/$3 $3
echo "$4" | passwd $3 --stdin > /dev/null 2>&1
#mkdir -p /data/home/$3
chown -R $3:$3  /data/home/$3
echo "$3 ALL=(ALL) ALL" >> /etc/sudoers
su - $3 -c " ssh-keygen -f ~/.ssh/id_rsa -P '' && cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys &&chmod go-w /data/home/$3"

# Copy  Aligo scripts file structure
AWS=$(which aws)

$AWS s3 cp s3://$SOCA_INSTALL_BUCKET/$SOCA_INSTALL_BUCKET_FOLDER/soca.tar.gz /root
mkdir -p /apps/soca/$SOCA_CONFIGURATION
tar -xvf /root/soca.tar.gz -C /apps/soca/$SOCA_CONFIGURATION --no-same-owner

mkdir -p /apps/soca/$SOCA_CONFIGURATION/cluster_manager/logs
chmod +x /apps/soca/$SOCA_CONFIGURATION/cluster_manager/aligoqstat.py

# Generate default queue_mapping file based on default AMI choosen by customer
cat <<EOT >> /apps/soca/$SOCA_CONFIGURATION/cluster_manager/settings/queue_mapping.yml
# This manage automatic provisioning for your queues
# These are default values. Users can override them at job submission
# https://awslabs.github.io/scale-out-computing-on-aws/tutorials/create-your-own-queue/
queue_type:
  compute:
    queues: ["high", "normal", "low"]
    # Uncomment to limit the number of concurrent running jobs
    # max_running_jobs: 50
    # Uncomment to limit the number of concurrent running instances
    # max_provisioned_instances: 30
    # Queue ACLs:  https://awslabs.github.io/scale-out-computing-on-aws/tutorials/manage-queue-acls/
    allowed_users: [] # empty list = all users can submit job
    excluded_users: [] # empty list = no restriction, ["*"] = only allowed_users can submit job
    # Queue mode (can be either fifo or fairshare)
    # queue_mode: "fifo"
    # Instance types restrictions: https://awslabs.github.io/scale-out-computing-on-aws/security/manage-queue-instance-types/
    allowed_instance_types: [] # Empty list, all EC2 instances allowed. You can restrict by instance type (Eg: ["c5.4xlarge"]) or instance family (eg: ["c5"])
    excluded_instance_types: [] # Empty list, no EC2 instance types prohibited.  You can restrict by instance type (Eg: ["c5.4xlarge"]) or instance family (eg: ["c5"])
    # List of parameters user can not override: https://awslabs.github.io/scale-out-computing-on-aws/security/manage-queue-restricted-parameters/
    restricted_parameters: []
    # Default job parameters: https://awslabs.github.io/scale-out-computing-on-aws/tutorials/integration-ec2-job-parameters/
    instance_ami: "$SOCA_INSTALL_AMI" # Required
    instance_type: "c5.large" # Required
    ht_support: "false"
    root_size: "10"
    #scratch_size: "100"
    #scratch_iops: "3600"
    #efa_support: "false"
    # .. Refer to the doc for more supported parameters
  desktop:
    queues: ["desktop"]
    # Uncomment to limit the number of concurrent running jobs
    # max_running_jobs: 50
    # Uncomment to limit the number of concurrent running instances
    # max_provisioned_instances: 30
    # Queue ACLs:  https://awslabs.github.io/scale-out-computing-on-aws/tutorials/manage-queue-acls/
    allowed_users: [] # empty list = all users can submit job
    excluded_users: [] # empty list = no restriction, ["*"] = only allowed_users can submit job
    # Queue mode (can be either fifo or fairshare)
    # queue_mode: "fifo"
    # Instance types restrictions: https://awslabs.github.io/scale-out-computing-on-aws/security/manage-queue-instance-types/
    allowed_instance_types: [] # Empty list, all EC2 instances allowed. You can restrict by instance type (Eg: ["c5.4xlarge"]) or instance family (eg: ["c5"])
    excluded_instance_types: [] # Empty list, no EC2 instance types prohibited.  You can restrict by instance type (Eg: ["c5.4xlarge"]) or instance family (eg: ["c5"])
    # List of parameters user can not override: https://awslabs.github.io/scale-out-computing-on-aws/security/manage-queue-restricted-parameters/
    restricted_parameters: []
    # Default job parameters: https://awslabs.github.io/scale-out-computing-on-aws/tutorials/integration-ec2-job-parameters/
    instance_ami: "$SOCA_INSTALL_AMI" # Required
    instance_type: "c5.large"  # Required
    ht_support: "false"
    root_size: "10"
    # .. Refer to the doc for more supported parameters
  test:
    queues: ["test"]
    # Uncomment to limit the number of concurrent running jobs
    # max_running_jobs: 50
    # Uncomment to limit the number of concurrent running instances
    # max_provisioned_instances: 30
    # Queue ACLs:  https://awslabs.github.io/scale-out-computing-on-aws/tutorials/manage-queue-acls/
    allowed_users: [] # empty list = all users can submit job
    excluded_users: [] # empty list = no restriction, ["*"] = only allowed_users can submit job
    # Queue mode (can be either fifo or fairshare)
    # queue_mode: "fifo"
    # Instance types restrictions: https://awslabs.github.io/scale-out-computing-on-aws/security/manage-queue-instance-types/
    allowed_instance_types: [] # Empty list, all EC2 instances allowed. You can restrict by instance type (Eg: ["c5.4xlarge"]) or instance family (eg: ["c5"])
    excluded_instance_types: [] # Empty list, no EC2 instance types prohibited.  You can restrict by instance type (Eg: ["c5.4xlarge"]) or instance family (eg: ["c5"])
    # List of parameters user can not override: https://awslabs.github.io/scale-out-computing-on-aws/security/manage-queue-restricted-parameters/
    restricted_parameters: []
    # Default job parameters: https://awslabs.github.io/scale-out-computing-on-aws/tutorials/integration-ec2-job-parameters/
    instance_ami: "$SOCA_INSTALL_AMI"  # Required
    instance_type: "c5.large"  # Required
    ht_support: "false"
    root_size: "10"
    #spot_price: "auto"
    #placement_group: "false"
    # .. Refer to the doc for more supported parameters
EOT

# Wait for PBS to restart
sleep 60


## Update PBS Hooks with the current script location
sed -i "s/%SOCA_CONFIGURATION/$SOCA_CONFIGURATION/g" /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_queue_acls.py
sed -i "s/%SOCA_CONFIGURATION/$SOCA_CONFIGURATION/g" /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_queue_instance_types.py
sed -i "s/%SOCA_CONFIGURATION/$SOCA_CONFIGURATION/g" /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_queue_restricted_parameters.py
sed -i "s/%SOCA_CONFIGURATION/$SOCA_CONFIGURATION/g" /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_licenses_mapping.py
sed -i "s/%SOCA_CONFIGURATION/$SOCA_CONFIGURATION/g" /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_project_budget.py

sed -i "s/%SOCA_CONFIGURATION/$SOCA_CONFIGURATION/g" /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/job_notifications.py

# Create Default PBS hooks
qmgr -c "create hook check_queue_acls event=queuejob"
qmgr -c "import hook check_queue_acls application/x-python default /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_queue_acls.py"
qmgr -c "create hook check_queue_instance_types event=queuejob"
qmgr -c "import hook check_queue_instance_types application/x-python default /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_queue_instance_types.py"
qmgr -c "create hook check_queue_restricted_parameters event=queuejob"
qmgr -c "import hook check_queue_restricted_parameters application/x-python default /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_queue_restricted_parameters.py"
qmgr -c "create hook check_licenses_mapping event=queuejob"
qmgr -c "import hook check_licenses_mapping application/x-python default /apps/soca/$SOCA_CONFIGURATION/cluster_hooks/queuejob/check_licenses_mapping.py"


# Reload config
systemctl restart pbs

# Create crontabs
echo "
## Cluster Analytics
* * * * * source /etc/environment; /apps/soca/$SOCA_CONFIGURATION/python/latest/bin/python3 /apps/soca/$SOCA_CONFIGURATION/cluster_analytics/cluster_nodes_tracking.py >> /apps/soca/$SOCA_CONFIGURATION/cluster_analytics/cluster_nodes_tracking.log 2>&1
@hourly source /etc/environment; /apps/soca/$SOCA_CONFIGURATION/python/latest/bin/python3 /apps/soca/$SOCA_CONFIGURATION/cluster_analytics/job_tracking.py >> /apps/soca/$SOCA_CONFIGURATION/cluster_analytics/job_tracking.log 2>&1
## Cluster Log Management
@daily  source /etc/environment; /bin/bash /apps/soca/$SOCA_CONFIGURATION/cluster_logs_management/send_logs_s3.sh >>/apps/soca/$SOCA_CONFIGURATION/cluster_logs_management/send_logs_s3.log 2>&1
## Cluster Management
* * * * * source /etc/environment;  /apps/soca/$SOCA_CONFIGURATION/python/latest/bin/python3  /apps/soca/$SOCA_CONFIGURATION/cluster_manager/nodes_manager.py >> /apps/soca/$SOCA_CONFIGURATION/cluster_manager/nodes_manager.py.log 2>&1

## Automatic Host Provisioning
* * * * * source /etc/environment;  /apps/soca/$SOCA_CONFIGURATION/python/latest/bin/python3 /apps/soca/$SOCA_CONFIGURATION/cluster_manager/dispatcher.py -c /apps/soca/$SOCA_CONFIGURATION/cluster_manager/settings/queue_mapping.yml -t compute
* * * * * source /etc/environment;  /apps/soca/$SOCA_CONFIGURATION/python/latest/bin/python3 /apps/soca/$SOCA_CONFIGURATION/cluster_manager/dispatcher.py -c /apps/soca/$SOCA_CONFIGURATION/cluster_manager/settings/queue_mapping.yml -t desktop
* * * * * source /etc/environment;  /apps/soca/$SOCA_CONFIGURATION/python/latest/bin/python3 /apps/soca/$SOCA_CONFIGURATION/cluster_manager/dispatcher.py -c /apps/soca/$SOCA_CONFIGURATION/cluster_manager/settings/queue_mapping.yml -t test
" | crontab -

S3PatchBucket="$5"
S3PatchFolder="$6"
#replace work node 

#add x
chmod +x /apps/soca/$SOCA_CONFIGURATION/cluster_web_ui/unix/puttygen

#add admin user
#sanitized_username="$3"
#sanitized_password="$4"

useradd -d /data/home/$DCV_USERNAME $DCV_USERNAME
echo "$DCV_USER_PASSWD" | passwd $DCV_USERNAME --stdin > /dev/null 2>&1
#mkdir -p /data/home/$DCV_USERNAME
chown -R $DCV_USERNAME:$DCV_USERNAME  /data/home/$DCV_USERNAME

# Configure DCV
mv /etc/dcv/dcv.conf /etc/dcv/dcv.conf.orig
IDLE_TIMEOUT=1440 # in minutes. Disconnect DCV (but not terminate the session) after 1 day if not active
USER_HOME=/data/home/$DCV_USERNAME
DCV_STORAGE_ROOT="$USER_HOME/storage-root" 
# Create the storage root location if needed
mkdir -p $DCV_STORAGE_ROOT
chown $DCV_USERNAME:$DCV_USERNAME $DCV_STORAGE_ROOT

echo -e """
[license]
[log]
[session-management]
virtual-session-xdcv-args=\"-listen tcp\"
[session-management/defaults]
[session-management/automatic-console-session]
storage-root=\"$DCV_STORAGE_ROOT\"
[display]
# add more if using an instance with more GPU
cuda-devices=[\"0\"]
[display/linux]
gl-displays = [\":1.0\"]
[display/linux]
use-glx-fallback-provider=false
[connectivity]
#web-url-path=\"/$DCV_HOST_ALTNAME\"
idle-timeout=$IDLE_TIMEOUT
[security]
#auth-token-verifier=\"$SOCA_DCV_AUTHENTICATOR\"
no-tls-strict=true
os-auto-lock=false
""" > /etc/dcv/dcv.conf

# Start DCV server
sudo systemctl enable dcvserver
sudo systemctl stop dcvserver
sleep 5
sudo systemctl start dcvserver

systemctl stop firewalld
systemctl disable firewalld

# Start X
systemctl isolate graphical.target

# Start Session
echo "Launching session ... : dcv create-session --user $DCV_USERNAME --owner $DCV_USERNAME --type virtual --storage-root "$DCV_STORAGE_ROOT" $SOCA_DCV_SESSION_ID"
dcv create-session --user $DCV_USERNAME --owner $DCV_USERNAME --type virtual --storage-root "$DCV_STORAGE_ROOT" $DCV_USERNAME
echo $?
sleep 5

# Final reboot is needed to update GPU drivers if running GPU instance. Reboot will be triggered by ComputeNodePostReboot.sh
if [[ "${GPU_INSTANCE_FAMILY[@]}" =~ "${INSTANCE_FAMILY}" ]];
then
  echo "@reboot dcv create-session --owner $DCV_USERNAME --storage-root \"$DCV_STORAGE_ROOT\" $DCV_USERNAME # Do Not Delete"| crontab - -u $DCV_USERNAME
#  exit 3 # notify ComputeNodePostReboot.sh to force reboot
else
  echo "@reboot dcv create-session --owner $DCV_USERNAME --storage-root \"$DCV_STORAGE_ROOT\" $DCV_USERNAME # Do Not Delete"| crontab - -u $DCV_USERNAME
#  exit 0
fi


# Check if the Cluster is fully operational

# Verify PBS
if [ -z "$(pgrep pbs)" ]
    then
    echo -e "
    /!\ /!\ /!\ /!\ /!\ /!\ /!\ /!\
    ERROR WHILE CREATING ALIGO HPC
    *******************************
    PBS SERVICE NOT DETECTED
    ********************************
    The USER-DATA did not run properly
    Please look for any errors on /var/log/message | grep cloud-init
    " > /etc/motd
    exit 1
fi

# Cluster is ready
echo -e "
   _____  ____   ______ ___
  / ___/ / __ \ / ____//   |
  \__ \ / / / // /    / /| |
 ___/ // /_/ // /___ / ___ |
/____/ \____/ \____//_/  |_|
Cluster: $SOCA_CONFIGURATION
> source /etc/environment to load SOCA paths
" > /etc/motd


# Clean directories
rm -rf /root/pbspro-18.1.4*
rm -rf /root/*.sh

# Install OpenMPI
# This will take a while and is not system blocking, so adding at the end of the install process
mkdir -p /apps/soca/$SOCA_CONFIGURATION/openmpi/installer
cd /apps/soca/$SOCA_CONFIGURATION/openmpi/installer

wget $OPENMPI_URL
if [[ $(md5sum $OPENMPI_TGZ | awk '{print $1}') != $OPENMPI_HASH ]];  then
    echo -e "FATAL ERROR: Checksum for OpenMPI failed. File may be compromised." > /etc/motd
    exit 1
fi

tar xvf $OPENMPI_TGZ
cd openmpi-$OPENMPI_VERSION
./configure --prefix=/apps/soca/$SOCA_CONFIGURATION/openmpi/$OPENMPI_VERSION
make
make install
