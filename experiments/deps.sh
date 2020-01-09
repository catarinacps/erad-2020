#!/bin/bash
#SBATCH --time=3:00:00
#SBATCH --chdir=.
#SBATCH --output=/home/users/hcpsilva/slurm_outputs/%x_%j.out
#SBATCH --error=/home/users/hcpsilva/slurm_outputs/%x_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=hcpsilva@inf.ufrgs.br

# more robust script
set -euo pipefail

# to install spack dependencies
function spack_install_spec {
    SPEC=$1
    ARCH=$2

    name_version=${SPEC%%[~|+|^]*}
    dir_name=$(echo $name_version | tr '@' '-')

    # if we fall here, we have already installed the package
    [ -d $dir_name ] && return 0

    echo "${name_version} not yet installed!"
    mkdir $dir_name
    spack install --keep-stage $SPEC arch=$ARCH
    spack view -d true soft -i $dir_name $SPEC arch=$ARCH

    [ ! -f installs.log ] && echo "SPECS HERE INSTALLED" > installs.log
    echo >> installs.log
    echo "PACKAGE:\t${name_version}" >> installs.log
    echo "SPEC:\t${SPEC}" >> installs.log
}

INSTALL_DIR=$1/$SLURM_JOB_PARTITION
EXP_DIR=$2
SPACK_DIR=${3:-$HOME/spack-erad}

pushd $HOME

if [ ! -d $SPACK_DIR ]; then
    echo "spack not yet installed!"
    git clone http://gitlab+deploy-token-127235:BZMob8RJoRPZAdLtsstX@gitlab.com/viniciusvgp/customSpack.git $SPACK_DIR
    pushd $SPACK_DIR
    ./install_spack.sh -symr
    popd
fi

. $SPACK_DIR/src/spack/share/spack/setup-env.sh

# find available compilers for this machine
spack compiler find

# get current node info
arch=$(spack arch)

# create the install dir if there isn't one
[ ! -d $INSTALL_DIR ] && mkdir -p $INSTALL_DIR

pushd $INSTALL_DIR

echo "--> INSTALLING DEPENDENCIES"

while read -r method spec; do
    echo $method $spec

    case $method in
        spack)
            spack_install_spec $spec $arch
            ;;
        manual)
            $EXP_DIR/${spec//@/-}.sh
            ;;
        *)
            echo
            echo "ERROR: method not supported..."
            exit
            ;;
    esac
done < $EXP_DIR/exp.deps

echo
echo "--> DONE"

popd
popd
