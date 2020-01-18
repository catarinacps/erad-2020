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
    OVER=$3

    name_version=${SPEC%%[~|+|^]*}
    dir_name=$PWD/$(tr '@' '-' <<<$name_version)

    # if we fall here, we have already installed the package
    [ -d $dir_name/lib ] && [ $OVER = false ] && return 0

    flags="--keep-stage -y"

    echo "${name_version} not yet installed!"
    if [ $OVER != false ]; then
        rm -rf $dir_name
        flags+=" --overwrite"
    fi

    [ $OVER = strong ] && spack uninstall -fy $SPEC arch=$ARCH

    mkdir -p $dir_name
    spack install $flags $SPEC arch=$ARCH
    spack view -d true soft -i $dir_name $SPEC arch=$ARCH
    spack find -l

    [ ! -f installs.log ] && echo "SPECS HERE INSTALLED" > installs.log
    echo >> installs.log
    echo -e "PACKAGE:\t${name_version}" >> installs.log
    echo -e "SPEC:\t${SPEC}" >> installs.log
}

function source_install_spec {
    SPEC=$1
    EXP_DIR=$2
    OVER=$3

    name_version=$(tr '@' '-' <<<${SPEC%%[~|+|^]*})
    prefix=$PWD/$name_version
    repo=$prefix/repo

    # if we fall here, we have already installed the package
    [ -d $prefix/lib ] && [ $OVER = false ] && exit 0

    [ $OVER != false ] && rm -rf $prefix

    echo "${name_version} not yet installed!"

    # install by the provided shell install script
    mkdir -p $prefix
    ${EXP_DIR}/${name_version}.sh $prefix/ $repo

    [ ! -f installs.log ] && echo "SPECS HERE INSTALLED" > installs.log
    echo >> installs.log
    echo -e "PACKAGE:\t${name_version}" >> installs.log
    echo -e "SPEC:\t${SPEC}" >> installs.log
}

INSTALL_DIR=$1
EXP_DIR=$2
SPACK_DIR=$3
OVERWRITE=$4

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
            spack_install_spec $spec $arch $OVERWRITE
            ;;
        manual)
            source_install_spec $spec $EXP_DIR $OVERWRITE
            ;;
        *)
            echo
            echo "ERROR: method not supported..."
            exit 128
            ;;
    esac
done < $EXP_DIR/exp.deps

echo
echo "--> DONE"

popd
popd
