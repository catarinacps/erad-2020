#!/bin/bash
set -euo pipefail

[ -d libomp-6.0 ] && exit

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
