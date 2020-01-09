#!/bin/bash
set -euo pipefail

INSTALL_DIR=$1
LIBOMP_DIR=$INSTALL_DIR/libomp-6.0

[ -d $LIBOMP_DIR ] && exit

echo "libomp not yet installed!"
pip install --user lit
mkdir $LIBOMP_DIR
git clone https://github.com/llvm-mirror/openmp.git $LIBOMP_DIR/openmp
pushd $LIBOMP_DIR/openmp
git checkout release_60
mkdir build
pushd build
LLVM_PATHS=$(find /usr/lib -name 'llvm-[0-9]*' | sed -e 's/$/\/bin/' | paste -s -d':' -)
export PATH+=:$LLVM_PATHS
cmake \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_INSTALL_PREFIX=$LIBOMP_DIR \
    -DLIBOMP_OMPT_SUPPORT=on \
    -DLIBOMP_OMPT_OPTIONAL=on \
    -DLIBOMP_STATS=on \
    ..
make -j
make -j install
popd
popd