#!/bin/bash
# more robust script
set -euo pipefail

function usage()
{
    echo "COMMAND:"
    echo "  $0 [OPTIONS] <EXP_ID> [REPO_DIRECTORY]"
    echo
    echo "  WHERE <EXP_ID> is the identificator of the experiment"
    echo
    echo "  WHERE [OPTIONS] can be any of the following, in no particular order:"
    echo "    -h | --help"
    echo "      shows this message and exits"
    echo "    -d | --dry"
    echo "      prints what it would do instead of actually doing it"
    echo "    -u | --update"
    echo "      updates the repo before running any commands"
    echo "    -i | --install[=]path/to/the/installs"
    echo "      use another dir instead of the default $HOME/Installs/spack"
    echo "    -p | --partitions[=]list,of,partitions,comma,separated"
    echo "      define the desired partitions to be used (default: cei)"
    echo "    -n | --nodes[=]list,of,nodes,comma,separated"
    echo "      define the desired nodes to be used"
    echo "      WARNING: this option disables usage of the partition list!"
    echo "    -l | --local"
    echo "      install all packages locally in each machine"
    echo "      WARNING: probably won't work because of timeouts in spack"
    echo
    echo "  WHERE [REPO_DIRECTORY] is the *full* path to the repository"
    echo "    It is presumed that you are in it, if you don't provide this argument"
}

for i in "$@"; do
    case $i in
        -h|--help)
            echo "USAGE:"
            echo
            usage
            exit
            ;;
        -d|--dry)
            DRY=true
            shift
            ;;
        -u|--update)
            UPDATE=true
            shift
            ;;
        --install=*)
            INSTALL_DIR=${i#*=}
            shift
            ;;
        -i|--install)
            shift
            INSTALL_DIR=$1
            shift
            ;;
        --partitions=*)
            PARTITIONLIST=$(tr ',' ' ' <<<${i#*=})
            shift
            ;;
        -p|--partitions)
            shift
            PARTITIONLIST=$(tr ',' ' ' <<<$1)
            shift
            ;;
        --nodes=*)
            NODELIST=$(tr ',' '\n' <<<${i#*=})
            PARTITIONLIST=$(sed -E 's/([0-9]+)//g' <<<$NODELIST | uniq | xargs)
            shift
            ;;
        -n|--nodes)
            shift
            NODELIST=$(tr ',' '\n' <<<$1)
            PARTITIONLIST=$(sed -E 's/([0-9]+)//g' <<<$NODELIST | uniq | xargs)
            shift
            ;;
        -l|--local)
            INSTALL_DIR=/scratch/$USER/installs
            LOCAL=true
            shift
            ;;
    esac
done

# directory with needed dependencies installed
INSTALL_DIR=${INSTALL_DIR:-$HOME/Installs/spack}

# the experiment id
EXPERIMENT_ID=$1

# the work (repo) dir
REPO_DIR=${2:-$(pwd)}

# dry run boolean
DRY=${DRY:-false}

# default run partition
PARTITIONLIST=${PARTITIONLIST:-cei}

# update boolean
UPDATE=${UPDATE:-false}

# local install boolean
LOCAL=${LOCAL:-false}

if [[ $REPO_DIR != /* ]]; then
    echo "Path to repository is not absolute, please use the absolute path..."
    exit
fi

if [[ $INSTALL_DIR != /* ]]; then
    echo "Path to installation dir is not absolute, please use the absolute path..."
    exit
fi

EXP_DIR=$(find $REPO_DIR -type d -path "*/experiments/$EXPERIMENT_ID")
if [ ! -n "$EXP_DIR" ]; then
    echo "There isn't any experiment with this ID..."
    exit
fi

pushd $REPO_DIR

# update the repo?
[ $UPDATE = true ] && git pull

for partition in $PARTITIONLIST; do
    # lets install all needed dependencies first
    echo "Launching dependency installing job for partition $partition!"
    if [ $DRY = true -a $LOCAL != true ]; then
        echo "sbatch"
        echo "-p $partition"
        echo "-N 1"
        echo "-J dependencies_${EXPERIMENT_ID}_${partition}"
        echo "-W"
        echo "$EXP_DIR/deps.sh $INSTALL_DIR"
        echo
    elif [ $LOCAL != true ]; then
        sbatch \
            -p ${partition} \
            -N 1 \
            -J dependencies_${EXPERIMENT_ID}_${partition} \
            -W \
            $EXP_DIR/deps.sh $INSTALL_DIR
    fi
    echo "... and done!"
    echo

    # change the gppd-info to sinfo when porting
    ALLNODES=$(gppd-info --long --Node -S NODELIST -p $partition -h | awk '{print $1 "_" $5}')
    if [ -z ${NODELIST+x} ]; then
        nodes=$(paste -s -d" " - <<<$ALLNODES)
    else
        nodes=$(grep "'$(grep $partition <<<$NODELIST)'" <<<$ALLNODES | paste -s -d" " -)
    fi

    for execution in $nodes; do
        # launch the slurm script for this node
        echo "Launching job for node ${execution%%_*}..."
        if [ $DRY = true ]; then
            echo "sbatch"
            echo "-p ${partition}"
            echo "-w ${execution%%_*}"
            echo "-c ${execution#*_}"
            echo "-J qr_analysis_${EXPERIMENT_ID}"
            echo "$EXP_DIR/exp.slurm $EXPERIMENT_ID $EXP_DIR $INSTALL_DIR $LOCAL"
            echo
        else
            sbatch \
                -p ${partition} \
                -w ${execution%%_*} \
                -c ${execution#*_} \
                -J qr_analysis_${EXPERIMENT_ID} \
                $EXP_DIR/exp.slurm $EXPERIMENT_ID $EXP_DIR $INSTALL_DIR $LOCAL
        fi
    done
done

popd
