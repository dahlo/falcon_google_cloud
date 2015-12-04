alias l='ls -l'
alias ll='ls -la'

# create mount point
sudo mkdir -p /mnt/shared
sudo chmod a+w /mnt/shared

# mount disk
sudo /usr/share/google/safe_format_and_mount -m "mkfs.ext4 -F" /dev/sdb /mnt/shared

# sort out the gluster data sharing
sudo apt-get install -y glusterfs-server python-virtualenv python-dev git htop vim
sudo mkdir /shared # make it world writable? or at least the user
sudo chmod a+w /shared
sudo gluster volume create shared transport tcp frontend001:/mnt/shared/brick
sudo gluster volume start shared
echo "frontend001:/shared /shared glusterfs   defaults,_netdev    0   0" | sudo tee -a /etc/fstab
sudo mount /shared

# install gluster and mount share on all compute nodes
CMD="sudo apt-get install -y glusterfs-client time && sudo mkdir /shared && echo 'frontend001:/shared /shared glusterfs   defaults,_netdev    0   0' | sudo tee -a /etc/fstab && sudo mount /shared"
for node in $(grep -o "compute.*" /etc/hosts); do ssh $node "$CMD" ; done

# sort out the gridengine parallell environment
sudo qconf -am $USER
qconf -au $USER users

# qconf -aattr hostgroup hostlist $(hostname) @allhosts
for node in $(grep -o "compute.*" /etc/hosts); do qconf -aattr queue slots "[$node=2]" all.q; done
for node in $(grep -o "compute.*" /etc/hosts); do sudo qconf -mattr exechost complex_values slots=2 ${node}; done

#qconf -de frontend001



# create parallell environment # use 
echo """pe_name            smp
slots              9999
user_lists         NONE
xuser_lists        NONE
start_proc_args    /bin/true
stop_proc_args     /bin/true
allocation_rule    \$fill_up 
control_slaves     FALSE
job_is_first_task  FALSE
urgency_slots      min
accounting_summary FALSE""" > smp.tmp
qconf -Ap smp.tmp
rm smp.tmp



# include parallell environment in the queue
qconf -mattr queue pe_list smp all.q

# enablle resubmission of failed jobs
qconf -sconf > global
sed -i "s/reschedule_unknown           00:00:00/reschedule_unknown           00:05:00/g" global
qconf -Mconf global
rm global








### -------------- the code below should be in various parts of 02_run_on_frontend_node_to_manage_falcon.sh
### it works to just run all the commands in serial and it will install and launch a test run of falcon though



cd /shared

git clone git://github.com/PacificBiosciences/FALCON-integrate.git
cd FALCON-integrate
WORK=$PWD
FC=$WORK/fc_env

# Python virtualenv
virtualenv $FC
## New python executable in /home/UNIXHOME/jchin/task2014/falcon_pb_github/fc_env/bin/python
## Installing setuptools, pip, wheel...done.

# Activate the virtual environment.
. $FC/bin/activate
which python
## $WORK/fc_env/bin/python

# Fetch submodules.
git submodule update --init

## Submodule 'DALIGNER' (git://github.com/pb-jchin/DALIGNER.git) registered for path 'DALIGNER'
## Submodule 'DAZZ_DB' (git://github.com/pb-jchin/DAZZ_DB.git) registered for path 'DAZZ_DB'
## Submodule 'FALCON' (git://github.com/PacificBiosciences/FALCON.git) registered for path 'FALCON'
## Submodule 'pypeFLOW' (git://github.com/PacificBiosciences/pypeFLOW.git) registered for path 'pypeFLOW'

# Install dependencies.

cd pypeFLOW
python setup.py install
cd ..

cd FALCON
python setup.py install
cd ..

cd DAZZ_DB/
make
cp DBrm DBshow DBsplit DBstats fasta2DB $FC/bin/
cd ..

cd DALIGNER
make
cp daligner daligner_p DB2Falcon HPCdaligner LA4Falcon LAmerge LAsort  $FC/bin
cd ..

# Test the installation.
mkdir -p ecoli_test
cd ecoli_test/
mkdir -p data
cd data
wget https://www.dropbox.com/s/tb78i5i3nrvm6rg/m140913_050931_42139_c100713652400000001823152404301535_s1_p0.1.subreads.fasta
wget https://www.dropbox.com/s/v6wwpn40gedj470/m140913_050931_42139_c100713652400000001823152404301535_s1_p0.2.subreads.fasta
wget https://www.dropbox.com/s/j61j2cvdxn4dx4g/m140913_050931_42139_c100713652400000001823152404301535_s1_p0.3.subreads.fasta
cd ..
find data -name "*.fasta" > input.fofn

# prepare the run template
cp $WORK/FALCON/examples/fc_run_ecoli.cfg .
sed -i "s/jobqueue = your_queue/jobqueue = all.q/g" fc_run_ecoli.cfg

# tell every job to request 2 slots only and enable restart
sed -i "s/smp [[:digit:]]\+/smp 1 -r y/g" fc_run_ecoli.cfg


# run the analysis
fc_run.py fc_run_ecoli.cfg

