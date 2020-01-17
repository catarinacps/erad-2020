#!/bin/bash
INSTALL_DIR=$1
REPO_DIR=$2

pip install --user lit
git clone https://github.com/llvm-mirror/openmp.git $REPO_DIR
pushd $REPO_DIR
git checkout release_60
mkdir build
pushd build
LLVM_PATHS=$(find /usr/lib -name 'llvm-[0-9]*' | sed -e 's/$/\/bin/' | paste -s -d':' -)
export PATH+=:$LLVM_PATHS
cmake \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
    -DLIBOMP_OMPT_SUPPORT=on \
    -DLIBOMP_OMPT_OPTIONAL=on \
    -DLIBOMP_STATS=on \
    ..
make -j
make -j install
popd
popd

rm -rf $REPO_DIR
