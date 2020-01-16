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
RAND_SEED=15195

# go to the scratch dir to execute our operations
cd $SCRATCH

# clean up my scratch dir
rm -rf *

STARPU_PATH=$(readlink -f $INSTALL/starpu-1.3.1)
LIBOMP_PATH=$(readlink -f $INSTALL/libomp-6.0)
LAPACK_PATH=$(readlink -f $INSTALL/netlib-lapack-3.8.0)
SCOREP_PATH=$(readlink -f $INSTALL/scorep-6.0)
HDF5_PATH=$(readlink -f $INSTALL/hdf5-1.10.5)
LIBKOMP_PATH=$(readlink -f $INSTALL/libkomp-master)
KSTAR_PATH=$(readlink -f $INSTALL/kstar-master)

PATH+=:$STARPU_PATH/bin
PATH+=:$SCOREP_PATH/bin
PATH+=:$KSTAR_PATH/bin
PATH+=:$LIBKOMP_PATH/bin
export PATH=$PATH

PKG_CONFIG_PATH+=:$STARPU_PATH/lib/pkgconfig
PKG_CONFIG_PATH+=:$LAPACK_PATH/lib/pkgconfig
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH

# prepare env variables
threads_per_core=$(lscpu | grep "per core" | awk '{print $4}')
real_core_count=$((${SLURM_CPUS_ON_NODE} / ${threads_per_core:-1}))

export STARPU_NCPU=$real_core_count
export STARPU_FXT_TRACE=1

export OMP_NUM_THREADS=$real_core_count
export OMP_PLACES=cores
export OMP_PROC_BIND=true
export OMP_TOOL=enabled

export SCOREP_ENABLE_PROFILING=true
export SCOREP_ENABLE_TRACING=true
export SCOREP_VERBOSE=true
export SCOREP_TIMER=gettimeofday
# why 8G?
export SCOREP_TOTAL_MEMORY=8G

export KAAPI_RECORD_TRACE=1
export KAAPI_RECORD_MASK=compute,omp,perfctr
export KAAPI_PERF_EVENTS=TASK,TASKSPAWN
export KAAPI_TASKPERF_EVENTS=work,time
export KAAPI_DISPLAY_PERF=full

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

    mkdir -p results/$run_id

    if [[ $runtime = starpu ]] || [[ $runtime = kstar_starpu ]]; then
        export STARPU_FXT_PREFIX=results/$run_id
        LD_LIBRARY_PATH+=:$HDF5_PATH/lib
        LD_LIBRARY_PATH+=:$STARPU_PATH/lib
    elif [[ $runtime = kstar_starpu ]]; then
        LD_LIBRARY_PATH+=:$KSTAR_PATH/lib
    elif [[ $runtime = openmp ]]; then
        LD_LIBRARY_PATH+=:$LIBOMP_PATH/lib
    elif [[ $runtime = libkomp_gcc ]] || [[ $runtime = libkomp_clang ]]; then
        export LD_PRELOAD=$LIBKOMP_PATH/lib/trace-libomp.so
        LD_LIBRARY_PATH+=:$LIBKOMP_PATH/lib
    elif [[ $runtime = libgomp ]]; then
        export SCOREP_EXPERIMENT_DIRECTORY=results/$run_id
    fi

    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH

    # execute given runtime and log results
    timeout 2h ./code/build/block_qr_$runtime \
         $matrix \
         $num_blocks \
         $RAND_SEED \
         $MAXVAL > $log_file 2>&1

    # get compute and total times from output
    ctime=$(grep -w compute_time $log_file | awk '{print $2}')
    ttime=$(grep -w total_time $log_file | awk '{print $2}')

    case $runtime in
        ompt)
            mv events.out results/$run_id
            ;;
        libkomp_gcc|libkomp_clang)
            mv /tmp/events.*.evt results/$run_id
            pushd results/$run_id
            katracereader --csv events.*
            popd
            mv stat.* results/$run_id
            ;;
    esac

    # add the execution data to the csv
    echo ${HOST},${matrix},${num_blocks},${runtime},${ctime},${ttime} >> $results_csv

    echo

    export LD_PRELOAD=
done < $EXP_DIR/runs.plan${PLAN_SUFFIX:-}

# gather node info
./code/scripts/node_info.sh > env.node

# create the data dir if it isn't already there
[ ! -d $EXP_DIR/data ] && mkdir $EXP_DIR/data

# zip everything and commit to EXP_DIR
tar czf $EXP_DIR/data/${EXP_NAME}_data.tar.gz *

popd
rm -rf $SCRATCH/*
