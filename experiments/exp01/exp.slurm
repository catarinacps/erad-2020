#!/bin/bash
#SBATCH --time=24:00:00
#SBATCH --chdir=.
#SBATCH --output=/home/users/hcpsilva/slurm_outputs/%x_%j.out
#SBATCH --error=/home/users/hcpsilva/slurm_outputs/%x_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=hcpsilva@inf.ufrgs.br

# more robust script
# set -euo pipefail

# parameters:
# the experiment ID, defined in the lab-book
EXP_ID=$1
# the experiment directory
EXP_DIR=$2
# the path to the directory where we'll find the needed packages
INSTALL=$3
# are we splitting plans?
PLAN_SUFFIX=${4:+.${SLURM_JOB_PARTITION}.}${4:-}

# node name
HOST=$(hostname)

# maximum element value (defined in experiment design)
MAXVAL=100

# experiment name (which is the ID and the machine and its core count)
EXP_NAME=${EXP_ID}_${HOST}_${SLURM_CPUS_ON_NODE}

# seed generated in project design
RAND_SEED=86229

# go to the scratch dir to execute our operations
cd $SCRATCH

# clean up my scratch dir
rm -rf *

STARPU_PATH=$(readlink -f $INSTALL/starpu-1.3.1)
LIBOMP_PATH=$(readlink -f $INSTALL/libomp-6.0)
LAPACK_PATH=$(readlink -f $INSTALL/netlib-lapack-3.8.0)
HDF5_PATH=$(readlink -f $INSTALL/hdf5-1.10.5)
LIBKOMP_PATH=$(readlink -f $INSTALL/libkomp-master)
KSTAR_PATH=$(readlink -f $INSTALL/kstar-master)

PATH+=:$STARPU_PATH/bin
PATH+=:$KSTAR_PATH/bin
export PATH=$PATH

PKG_CONFIG_PATH+=:$STARPU_PATH/lib/pkgconfig
PKG_CONFIG_PATH+=:$LAPACK_PATH/lib/pkgconfig
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH

# prepare env variables
threads_per_core=$(lscpu | grep "per core" | awk '{print $4}')
real_core_count=$((${SLURM_CPUS_ON_NODE} / ${threads_per_core:-1}))
export STARPU_NCPU=$real_core_count
export OMP_NUM_THREADS=$real_core_count
export STARPU_FXT_TRACE=0
export KAAPI_RECORD_TRACE=0
export OMP_PLACES=cores
export OMP_PROC_BIND=true
export KMP_STACKSIZE=$((1024*1024*34))

echo "Environment variables set up!"

# prepare our directory
mkdir $EXP_NAME
pushd $EXP_NAME

# copy the code folder
cp -r $EXP_DIR/code code
mkdir results

pushd code
make clean
make all LIBOMP_LIB="$LIBOMP_PATH/lib" LIBOMP_INC="$LIBOMP_PATH/include"
ln -s $PWD/build/block_qr_libomp $PWD/build/block_qr_libkomp_clang
ln -s $PWD/build/block_qr_libgomp $PWD/build/block_qr_libkomp_gcc
popd

# init the results csv
results_csv=results/${HOST}_data.csv
echo "node,rep_id,matrix_size,block_size,runtime,compute_time,total_time" > $results_csv

# execute the experiment
while read -r id runtime matrix num_blocks; do
    echo "-> Parameters set to: $runtime $matrix $num_blocks"

    # output log file
    log_file=results/${runtime}_${matrix}_${num_blocks}_${id}.log

    # execute given runtime and log results

    LD_LIBRARY_PATH=$LAPACK_PATH/lib

    if [[ $runtime = starpu ]] || [[ $runtime = kstar_starpu ]]; then
        LD_LIBRARY_PATH+=:$HDF5_PATH/lib
        LD_LIBRARY_PATH+=:$STARPU_PATH/lib
    elif [[ $runtime = kstar_starpu ]]; then
        LD_LIBRARY_PATH+=:$KSTAR_PATH/lib
    elif [[ $runtime = openmp ]]; then
        LD_LIBRARY_PATH+=:$LIBOMP_PATH/lib
    elif [[ $runtime = libkomp_gcc ]] || [[ $runtime = libkomp_clang ]]; then
        LD_LIBRARY_PATH+=:$LIBKOMP_PATH/lib
    fi

    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH

    timeout 1h ./code/build/block_qr_$runtime \
            $matrix \
            $num_blocks \
            $RAND_SEED \
            $MAXVAL > $log_file 2>&1

    # get compute and total times from output
    ctime=$(grep -w compute_time $log_file | awk '{print $2}')
    ttime=$(grep -w total_time $log_file | awk '{print $2}')

    # add the execution data to the csv
    echo ${HOST},${id},${matrix},${num_blocks},${runtime},${ctime},${ttime} >> $results_csv

    echo
done < $EXP_DIR/runs.plan${PLAN_SUFFIX:-}

# gather node info
./code/scripts/node_info.sh > env.node

# create the data dir if it isn't already there
[ ! -d $EXP_DIR/data ] && mkdir $EXP_DIR/data

# zip everything and commit to EXP_DIR
tar czf $EXP_DIR/data/${EXP_NAME}_data.tar.gz *

popd
rm -rf $SCRATCH/* $SCRATCH/.installs
