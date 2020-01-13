#!/bin/bash
#SBATCH --time=24:00:00
#SBATCH --chdir=.
#SBATCH --output=/home/users/hcpsilva/slurm_outputs/%x_%j.out
#SBATCH --error=/home/users/hcpsilva/slurm_outputs/%x_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=hcpsilva@inf.ufrgs.br

# more robust script
set -euo pipefail

# parameters:
# the experiment ID, defined in the lab-book
EXP_ID=$1
# the experiment directory
EXP_DIR=$2
# the path to the directory where we'll find the needed packages
INSTALL=$3/$SLURM_JOB_PARTITION
# local run?
LOCAL=$4
# are we splitting plans?
PLAN_SUFFIX=${5:+.${SLURM_JOB_PARTITION}.}${5:-}

# node name
HOST=$(hostname)

# maximum element value (defined in experiment design)
MAXVAL=100

# experiment name (which is the ID and the machine and its core count)
EXP_NAME=${EXP_ID}_${HOST}_${SLURM_CPUS_ON_NODE}

# seed generated in project design
RAND_SEED=15195

# go to the scratch dir to execute our operations
cd $SCRATCH

# clean up my scratch dir
rm -rf *

# if the LOCAL argument is true, install everything locally
# (we presume that the path is $INSTALL is local)
[ $LOCAL = true ] && $EXP_DIR/deps.sh $INSTALL ./spack

STARPU_PATH=$(readlink -f $INSTALL/starpu-1.3.1)
LIBOMP_PATH=$(readlink -f $INSTALL/libomp-6.0)
LAPACK_PATH=$(readlink -f $INSTALL/netlib-lapack-3.8.0)
SCOREP_PATH=$(readlink -f $INSTALL/scorep-6.0)
HDF5_PATH=$(readlink -f $INSTALL/hdf5-1.10.5)
LIBKOMP_PATH=$(readlink -f $INSTALL/libkomp-master)
KSTAR_PATH=$(readlink -f $INSTALL/kstar-master)

PATH+=:$STARPU_PATH/bin
PATH+=:$SCOREP_PATH/bin
export PATH=$PATH

PKG_CONFIG_PATH+=:$STARPU_PATH/lib/pkgconfig
PKG_CONFIG_PATH+=:$LAPACK_PATH/lib/pkgconfig
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH

# prepare env variables
threads_per_core=$(lscpu | grep "per core" | awk '{print $4}')
real_core_count=$((${SLURM_CPUS_ON_NODE} / ${threads_per_core:-1}))
export STARPU_NCPU=$real_core_count
export OMP_NUM_THREADS=$real_core_count
export OMP_PLACES={0:$real_core_count}
export OMP_PROC_BIND=true

export SCOREP_ENABLE_PROFILING=true
export SCOREP_ENABLE_TRACING=true
export SCOREP_VERBOSE=true
export SCOREP_TIMER=gettimeofday
# why 8G?
export SCOREP_TOTAL_MEMORY=8G

echo "Environment variables set up!"

# prepare our directory
mkdir $EXP_NAME
pushd $EXP_NAME

# copy the code folder
cp -r $EXP_DIR/code code
mkdir results

mkdir results/libgomp
mkdir results/starpu
mkdir results/libomp

LIBGOMP_TRACE_DIR=$(readlink -f results)/libgomp
STARPU_TRACE_DIR=$(readlink -f results)/starpu
LIBOMP_TRACE_DIR=$(readlink -f results)/libomp

export STARPU_FXT_TRACE=1

export SCOREP_EXPERIMENT_DIRECTORY=$LIBGOMP_TRACE_DIR

pushd code
make clean
make all LIBOMP_LIB="$LIBOMP_PATH/lib" LIBOMP_INC="$LIBOMP_PATH/include"
ln -s $PWD/build/block_qr_libomp $PWD/build/block_qr_libkomp_clang
ln -s $PWD/build/block_qr_libgomp $PWD/build/block_qr_libkomp_gcc
popd

# init the results csv
results_csv=results/${HOST}_data.csv
echo "node,matrix_size,block_size,runtime,compute_time,total_time" > $results_csv

# execute the experiment
while read -r runtime matrix num_blocks; do
    echo "-> Parameters set to: $runtime $matrix $num_blocks"
    run_id=${runtime}_${matrix}_${num_blocks}

    # output log file
    log_file=results/${run_id}.log

    LD_LIBRARY_PATH=$(readlink -f code/lib):$LAPACK_PATH/lib

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

    # execute given runtime and log results
    ./code/build/block_qr_$runtime \
         $matrix \
         $num_blocks \
         $RAND_SEED \
         $MAXVAL > $log_file 2>&1

    # get compute and total times from output
    ctime=$(grep -w compute_time $log_file | awk '{print $2}')
    ttime=$(grep -w total_time $log_file | awk '{print $2}')

    case $runtime in
        starpu)
            mv /tmp/prof_file_${USER}_0 $STARPU_TRACE_DIR/${run_id}.trace
            ;;
        scorep)
            pid=0
            for file in $(find . -maxdepth 1 -name 'scorep-prof*'); do
                mv $file $LIBGOMP_TRACE_DIR/${run_id}_${pid}.trace
                pid=$((pid+1))
            done
            ;;
        ompt)
            mv events.out $LIBOMP_TRACE_DIR/${run_id}.trace
            ;;
        libkomp_gcc|libkomp_clang)
            echo
            ;;
        kstar_starpu)
            echo
            ;;
    esac

    # add the execution data to the csv
    echo ${HOST},${matrix},${num_blocks},${runtime},${ctime},${ttime} >> $results_csv

    echo
done < $EXP_DIR/runs.plan${PLAN_SUFFIX:-}

# gather node info
./code/scripts/node_info.sh > env.node

# create the data dir if it isn't already there
[ ! -d $EXP_DIR/data ] && mkdir $EXP_DIR/data

# zip everything and commit to EXP_DIR
tar czf $EXP_DIR/data/${EXP_NAME}_data.tar.gz *

popd
rm -rf $SCRATCH/*
