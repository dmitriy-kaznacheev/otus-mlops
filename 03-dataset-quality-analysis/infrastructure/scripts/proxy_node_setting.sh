#!/bin/bash

USER="ubuntu"
HOME="/home/$USER"
PKEY_FILE="$HOME/.ssh/dataproc_key"
LOG_FILE="/var/log/infrastructure_setting.log"

#--- логирование ----------------------------------------------------------------------------------

function LOG() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') $1" | tee -a $LOG_FILE
}

function ERROR() {
    LOG "[ERR] $1"
}

function INFO() {
    LOG "[INF] $1"
}

#--- настройка yc-cli -----------------------------------------------------------------------------

INFO "yc-cli is installing..."
export HOME
curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
sudo chown -R $USER: $HOME/yandex-cloud
source $HOME/.bashrc
export PATH="$PATH:$HOME/yandex-cloud/bin"

if command -v yc &> /dev/null; then
    yc_version=$(yc --version)
    INFO "installation is complete: $yc_version"
else
    ERROR "installation aborted"
    exit 1
fi

INFO "yc-cli is configured"
yc config set token ${token}
yc config set cloud-id ${cloud}
yc config set folder-id ${folder}
sudo chown -R $USER: $HOME/.config

#--- настройка доступа публичного достпа для бакета -----------------------------------------------

INFO "set public access for the bucket"
yc storage bucket update \
  --name ${dst_bucket} \
  --public-read \
  --public-list \
  --public-config-read

#--- настройка подключения к мастер-ноде dataproc кластера ----------------------------------------

INFO "jq is installed for json parsing"
sudo apt-get update
sudo apt-get install -y jq

INFO "getting master node FQDN..."
MASTER_FQDN=$(yc compute instance list --format json | \
              jq -r '.[] | select(.labels.subcluster_role == "masternode") | .fqdn')
if [ -n "$MASTER_FQDN" ]; then
    INFO "master node FQDN: $MASTER_FQDN"
else
    ERROR "failed to get master node FQDN"
    exit 1
fi

INFO "сreated .ssh directory and configured private key"
mkdir -p $HOME/.ssh
echo "${ssh_private_key}" > $PKEY_FILE
chown $USER: $PKEY_FILE
chmod 600 $PKEY_FILE

INFO "added SSH configuration for master node connection"
cat <<EOF > $HOME/.ssh/config
Host dataproc-master
    HostName $MASTER_FQDN
    User $USER
    IdentityFile $PKEY_FILE
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
chown $USER: $HOME/.ssh/config
chmod 600 $HOME/.ssh/config

INFO "ssh-agent is configured"
eval $(ssh-agent -s)
echo "eval \$(ssh-agent -s)" >> $HOME/.bashrc
ssh-add $PKEY_FILE
echo "ssh-add $PKEY_FILE" >> $HOME/.bashrc

INFO "check the connection to the master node"
source $HOME/.bashrc
ssh -i $PKEY_FILE -o StrictHostKeyChecking=no $USER@$MASTER_FQDN \
       "echo 'Connection successful'"
if [ $? -eq 0 ]; then
    INFO "connection to the master node successful"
else
    ERROR "connection to the master node failed"
    exit 1
fi

#--- скрипт копирования s3-to-hdfs ----------------------------------------------------------------

INFO "create a copy2hdfs.sh script"
mkdir -p $HOME/scripts
cat <<EOF > $HOME/scripts/copy2hdfs.sh
#!/bin/bash
sudo -u hdfs hdfs dfs -mkdir ${hdfs_dir}
sudo -u hdfs hdfs dfs -chown $USER ${hdfs_dir}
hadoop distcp s3a://${src_bucket}/ ${hdfs_dir}/
hdfs dfs -ls ${hdfs_dir}
EOF

chmod +x $HOME/scripts/copy2hdfs.sh
scp -i $PKEY_FILE -o StrictHostKeyChecking=no $HOME/scripts/copy2hdfs.sh $USER@$MASTER_FQDN:$HOME/
ssh -i $PKEY_FILE -o StrictHostKeyChecking=no $USER@MASTER_FQDN "chmod +x ~/copy2hdfs.sh"

#--- скрипт для удаления spark-кластер ------------------------------------------------------------

INFO "create a destroy_spark.sh script"
mkdir -p $HOME/scripts
cat <<EOF > $HOME/scripts/destroy_spark.sh
#!/bin/bash
yc dataproc cluster delete mlops-dataproc-cluster
EOF

chmod +x $HOME/scripts/destroy_spark.sh

#--- скрипт для очистки данных и сохранения в бакет -----------------------------------------------

INFO "create dataset_cleanup.py script"
echo '${cleanup_script}' > $HOME/scripts/dataset_cleanup.py
sed -i "s/{{ s3_bucket }}/${dst_bucket}/g" $HOME/scripts/dataset_cleanup.py

chmod +x $HOME/scripts/dataset_cleanup.py
scp -i $PKEY_FILE -o StrictHostKeyChecking=no $HOME/scripts/dataset_cleanup.py $USER@$MASTER_FQDN:$HOME/
ssh -i $PKEY_FILE -o StrictHostKeyChecking=no $USER@MASTER_FQDN "chmod +x ~/dataset_cleanup.py"

INFO "findspark is installed for the dataset_cleanup.py script"
ssh -i $PKEY_FILE -o StrictHostKeyChecking=no $USER@MASTER_FQDN "pip install findspark"

#--- запуск скриптов ------------------------------------------------------------------------------

INFO "start data upload to the HDFS..."
ssh -i $PKEY_FILE -o StrictHostKeyChecking=no $USER@MASTER_FQDN "~/copy2hdfs.sh"

INFO "start cleanup of the dataset and store it to the bucket..."
ssh -i $PKEY_FILE -o StrictHostKeyChecking=no $USER@MASTER_FQDN "~/dataset_cleanup.py"

INFO "execution completed"

#--- запуск jupyter notebook ----------------------------------------------------------------------

# INFO "jupyter notebook running on port 8888"
# jupyter notebook --no-browser --ip 0.0.0.0 --port 8888

#--- настройка завершена --------------------------------------------------------------------------

INFO "proxy node configuration is complete"
