#!/bin/bash
#SBATCH --time=3:00:00
#SBATCH --chdir=.
#SBATCH --output=/home/users/hcpsilva/slurm_outputs/%x_%j.out
#SBATCH --error=/home/users/hcpsilva/slurm_outputs/%x_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=hcpsilva@inf.ufrgs.br

# more robust script
set -euo pipefail

INSTALL_DIR=$1/$SLURM_JOB_PARTITION
SPACK_DIR=${2:-$HOME/spack-erad}

pushd $HOME

if [ ! -d $SPACK_DIR ]; then
    echo "spack not yet installed!"
    git clone git@github.com:viniciusvgp/customSpack.git $SPACK_DIR
    $SPACK_DIR/install_spack.sh -symr
    . $SPACK_DIR/src/spack/share/spack/setup-env.sh
else
    . $SPACK_DIR/src/spack/share/spack/setup-env.sh
fi

# get current node info
ARCH=$(spack arch)

# create the install dir if there isn't one
[ ! -d $INSTALL_DIR ] && mkdir -p $INSTALL_DIR

pushd $INSTALL_DIR

if [ ! -d openblas-0.3.7 ]; then
    echo "OpenBLAS not yet installed!"
    mkdir openblas-0.3.7
    spack install openblas@0.3.7 arch=$ARCH
    spack view -d true soft openblas-0.3.7 openblas@0.3.7 arch=$ARCH
fi

if [ ! -d hdf5-1.10.5 ]; then
    echo "HDF5 not yet installed!"
    mkdir hdf5-1.10.5
    spack install hdf5@1.10.5 arch=$ARCH
    spack view -d true soft hdf5-1.10.5 hdf5@1.10.5 arch=$ARCH
fi

if [ ! -d starpu-1.3.1 ]; then
    echo "StarPU not yet installed!"
    mkdir starpu-1.3.1
    spack install starpu@1.3.1~fxt~poti~examples~mpi~openmp arch=$ARCH
    spack view -d true soft starpu-1.3.1 starpu@1.3.1~fxt~poti~examples~mpi~openmp arch=$ARCH
fi

if [ ! -d netlib-lapack-3.8.0 ]; then
    echo "lapack not yet installed!"
    mkdir netlib-lapack-3.8.0
    spack install netlib-lapack@3.8.0 arch=$ARCH
    spack view -d true soft netlib-lapack-3.8.0 netlib-lapack@3.8.0 arch=$ARCH
fi

if [ ! -d libomp-6.0 ]; then
    echo "libomp not yet installed!"
    pip install --user lit
    mkdir libomp-6.0
    git clone https://github.com/llvm-mirror/openmp.git libomp-6.0/openmp
    pushd libomp-6.0/openmp
    git checkout release_60
    mkdir build
    pushd build
    LLVM_PATHS=$(find /usr/lib -name 'llvm-[0-9]*' | sed -e 's/$/\/bin/' | paste -s -d':' -)
    export PATH+=:$LLVM_PATHS
    cmake -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR/libomp-6.0 -DLIBOMP_OMPT_SUPPORT=on -DLIBOMP_OMPT_OPTIONAL=on -DLIBOMP_STATS=on ..
    make -j
    make -j install
    popd
    popd
fi

if [ ! -d libkomp-master ]; then
    echo "libkomp not yet installed!"
    mkdir libkomp-master
    spack install --keep-stage libkomp@master+the+affinity+numa~tracing~papi+vardep arch=$ARCH
    spack view -d true soft libkomp-master libkomp@master+the+affinity+numa~tracing~papi+vardep arch=$ARCH
fi

if [ ! -d kstar-starpu-master ]; then
    echo "kstar not yet installed!"
    mkdir kstar-starpu-master
    spack install --keep-stage kstar@master+starpu^starpu@1.3.1~fxt~poti~examples~mpi~openmp arch=$ARCH
    spack view -d true soft kstar-starpu-master kstar@master+starpu^starpu@1.3.1~fxt~poti~examples~mpi~openmp arch=$ARCH
fi

popd
popd
