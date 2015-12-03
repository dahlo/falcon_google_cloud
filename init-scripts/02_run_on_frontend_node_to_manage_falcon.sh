#!/bin/bash
#
#SBATCH -J "FALCON test"
#SBATCH -A "b2014264"
#SBATCH -p "node"
#SBATCH -c 1
#SBATCH -t 01:00:00
#SBATCH -o "log.FALCON"
#SBATCH -e "log.error.FALCON"

#virtualenv -h >/dev/null 2>&1
#if [[ "$?" != "0" ]]
#then
#    source /home/martinn/.scripts/pyenv
#fi

INSTALL_DIR="$(pwd)/FALCON"

function remove {
    printf " -- Removing old FALCON directory                                         "
    
    if [ -d "$INSTALL_DIR" ]
    then
        rm -rf "$INSTALL_DIR"
    fi
    if [[ "$?" == "0" ]]
    then
        echo "done"
        return 0
    fi
    echo "FAIL"
    return 1   
}

function info {
    echo
    echo " -- System information"
    echo
    echo "    System     :  $(uname -a)"
    echo "    GCC        :  $(gcc --version | head -1)"
    echo "    PYTHON     :  $(python --version 2>&1)"
#    echo "    Modules    :$(module list 2>&1 | tail -1)"
    echo "    Install dir:  $INSTALL_DIR"
    echo
    return 0
}

function python_virtualenv { 
    printf " -- Activating Python virtual environment                                 "
    if [ ! -d "virtualenv-12.1.1" ]
    then
        echo
        printf "  + Downloading virtualenv 12.1.1                                         "
        wget https://pypi.python.org/packages/source/v/virtualenv/virtualenv-12.1.1.tar.gz -q
        if [[ "$?" == "0" ]]
        then
            echo "done"
        else
            echo "FAIL"
            return 1
        fi
        printf "  + Unpacking                                                             "
        tar xf virtualenv-12.1.1.tar.gz
        if [[ "$?" == "0" ]]
        then
            echo "done"
        else
            echo "FAIL"
            return 1
        fi 
        printf "  + Creating environment                                                  "
        virtualenv-12.1.1/virtualenv.py fc_env >log.virtual_env 2>&1 #--no-site-packages --always-copy $PWD/fc_env
        if [[ "$?" == "0" ]]
        then
            echo "done"
        else
            echo "FAIL"
            return 1
        fi
        printf "  + Activating environment                                                "
    fi
    . $PWD/fc_env/bin/activate
    if [[ "$?" == "0" ]]
    then
        echo "done"
    else
        echo "FAIL"
        return 1
    fi
    return 0
}

function install_pypeFLOW {
    printf "  + Installing pypeFLOW                                                   "
    
    git clone https://github.com/pb-jchin/pypeFLOW.git >log.FALCON 2>&1
    cd pypeFLOW
    python setup.py install >>log.pypeFLOW 2>&1
    cd ..
    
    echo "done"
    return 0
}

function install_FALCON {
    printf "  + Installing FALCON                                                     "

    git clone https://github.com/PacificBiosciences/FALCON.git >log.FALCON 2>&1
    cd FALCON
    python setup.py install >>log.FALCON 2>&1
    cd ..
    
    echo "done"
    return 0
}

function install_DAZZ_DB {
    printf "  + Installing DAZZ_DB                                                    "

    git clone https://github.com/pb-jchin/DAZZ_DB.git >log.DAZZ_DB 2>&1
    cd DAZZ_DB/
    make >>log.DAZZ_DB 2>&1
    cp DBrm DBshow DBsplit DBstats fasta2DB ../fc_env/bin/
    cd ..
    
    echo "done"
    return 0
}

function install_DALIGNER {
    printf "  + Installing DALIGNER                                                   "

    git clone https://github.com/pb-jchin/DALIGNER.git >log.DALIGNER 2>&1
    cd DALIGNER
    
    #
    # ADDED A "make" here, as 4fe0d39 does not compile DB2Falcon and LA4Falcon
    #
    #make
    
    git checkout 97b0c27a26164dbdd6dc52923855501ca3d14d45 >>log.DALIGNER 2>&1
    make >>log.DALIGNER
    cp daligner daligner_p DB2Falcon HPCdaligner LA4Falcon LAmerge LAsort  ../fc_env/bin
    cd ..
    
    echo "done"
    return 0
}

function install_falcon {
    if [ -d "$INSTALL_DIR" ]
    then
        echo "Install dir exists."
        return 1
    fi
    git --version >/dev/null
    if [[ "$?" == "127" ]]
    then
        echo "git is not installed, run apt-get install git and try again."
        return 127
    fi
    mkdir -p $INSTALL_DIR
    cd $INSTALL_DIR

    python_virtualenv
    echo " -- Installing FALCON packages"
    install_pypeFLOW
    install_FALCON
    install_DAZZ_DB
    install_DALIGNER
    cd ..
}

function test {
    cd $INSTALL_DIR
    . $INSTALL_DIR/fc_env/bin/activate
    if [ -d "ecoli_test" ]
    then
        printf " -- removing old test directory                                           "
        rm -r ecoli_test
        echo "done."
    fi
    echo " -- Preparing e-coli test"
    mkdir ecoli_test
    cd ecoli_test/
    
    printf "  + Downloading e-coli test data                                          "
    mkdir data
    cd data
    wget https://www.dropbox.com/s/tb78i5i3nrvm6rg/m140913_050931_42139_c100713652400000001823152404301535_s1_p0.1.subreads.fasta -q
    wget https://www.dropbox.com/s/v6wwpn40gedj470/m140913_050931_42139_c100713652400000001823152404301535_s1_p0.2.subreads.fasta -q
    wget https://www.dropbox.com/s/j61j2cvdxn4dx4g/m140913_050931_42139_c100713652400000001823152404301535_s1_p0.3.subreads.fasta -q
    cd ..
    echo "done"
    
    printf "  + Making project configuration files                                    "
    find $PWD/data -name "*.fasta" > input.fofn
    cp ../FALCON/examples/fc_run_ecoli.cfg .
    # tell the system to run jobs locally instead of using SGE
    # sed -i "2ijob_type = local" fc_run_ecoli.cfg
    
    # remove specific job queue
    sed -i "s/-q jobqueue//g" fc_run_ecoli.cfg
    
    # tell every job to request 2 slots only
    sed -i "s/smp .*/smp 1/g" fc_run_ecoli.cfg
    
    echo "done"
    
    echo " -- Running e-coli test"
    fc_run.py fc_run_ecoli.cfg

    echo
    echo " That's it. "
    echo
    
    return 0
}

if [[ "$1" == "" ]]
then
    echo "USAGE: ./$0 [remove] [install] [info] [test]"
else
    for arg in "$@"
    do
        [[ "$arg" == "remove" ]]  && remove
        [[ "$arg" == "install" ]] && install_falcon
        [[ "$arg" == "info" ]]    && info
        [[ "$arg" == "test" ]]    && test
    done 
fi