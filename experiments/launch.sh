#!/bin/bash
# more robust script
set -euo pipefail

function usage()
{
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
    echo "    -s | --split"
    echo "      split the execution plan between all nodes that ought to be used"
    echo "      WARNING: the splitting will occur between same-partition nodes only"
    echo "               i.e.: if more than one partition is listed, we'll repeat"
    echo "               the process in the other partitions"
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
        -s|--split)
            SPLIT=true
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

# the split plan boolean
SPLIT=${SPLIT:-false}

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

if [ $DRY = true ]; then
    DRYCMD=echo
else
    DRYCMD=
fi

pushd $REPO_DIR

# update the repo?
[ $UPDATE = true ] && git pull

for partition in $PARTITIONLIST; do
    # lets install all needed dependencies first
    echo "-> Launching dependency installing job for partition $partition!"
    if [ $LOCAL != true ]; then
        ${DRYCMD:-} sbatch \
            -p ${partition} \
            -N 1 \
            -J dependencies_${EXPERIMENT_ID}_${partition} \
            -W \
            $(dirname $EXP_DIR)/deps.sh $INSTALL_DIR $EXP_DIR
        echo
    fi
    echo "... and done!"
    echo

    # change the gppd-info to sinfo when porting
    ALLNODES=$(gppd-info --long --Node -S NODELIST -p $partition -h | awk '{print $1 "_" $5}')
    if [ -z ${NODELIST+x} ]; then
        nodes=$(paste -s -d" " - <<<$ALLNODES)
    else
        nodes=$(grep "$NODELIST" <<<$ALLNODES | paste -s -d" " -)
    fi

    # splits the plan if we were told to
    if [ $SPLIT = true ]; then
        num_nodes=$(wc -w <<<$nodes)
        ${DRYCMD:-} rm -f $EXP_DIR/runs.plan.${partition}.*
        ${DRYCMD:-} split -n l/$num_nodes -d -a 1 $EXP_DIR/runs.plan $EXP_DIR/runs.plan.${partition}.
    fi

    # counter to access the correct plan
    plan_part=${num_nodes:+0}

    for execution in $nodes; do
        # launch the slurm script for this node
        echo "Launching job for node ${execution%%_*}..."
        ${DRYCMD:-} sbatch \
            -p ${partition} \
            -w ${execution%%_*} \
            -c ${execution#*_} \
            -J qr_analysis_${EXPERIMENT_ID} \
            $EXP_DIR/exp.slurm $EXPERIMENT_ID $EXP_DIR $INSTALL_DIR $LOCAL ${plan_part:-}

        if [ ! -z ${plan_part+z} ]; then
            plan_part=$((plan_part+1))
        fi
    done

    echo
done

popd
