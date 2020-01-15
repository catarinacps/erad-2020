#!/bin/bash
# more robust script
set -euo pipefail

function usage {
cat << EOF
  $0 [OPTIONS] <EXP_ID> [REPO_DIRECTORY]

  WHERE <EXP_ID> is the identificator of the experiment

  WHERE [OPTIONS] can be any of the following, in no particular order:
    -h | --help
      shows this message and exits
    -d | --dry
      prints what it would do instead of actually doing it
    -u | --update
      updates the repo before running any commands
    -i | --install[=]path/to/the/installs
      use another dir instead of the default $HOME/Installs/spack
    --spack[=]path/to/spack
      use another spack dir instead of the default $HOME/spack-erad
    -p | --partitions[=]list,of,partitions,comma,separated
      define the desired partitions to be used (default: cei)
    -s | --split
      split the execution plan between all nodes that ought to be used
      WARNING: the splitting will occur between same-partition nodes only
               i.e.: if more than one partition is listed, we'll repeat
               the process in the other partitions
    -n | --nodes[=]list,of,nodes,comma,separated
      define the desired nodes to be used
      WARNING: this option disables usage of the partition list!
    -l | --local
      install all packages locally in each machine
      WARNING: probably won't work because of timeouts in spack
    -o | --overwrite
      force the reinstall of all packages listed as a dependency

  WHERE [REPO_DIRECTORY] is the *full* path to the repository
    It is presumed that you are in it, if you don't provide this argument
EOF
}

for i in "$@"; do
    case $i in
        -h|--help)
            echo "USAGE:"
            usage
            exit 0
            ;;
        --dry)
            DRY=echo
            shift
            ;;
        --update)
            git pull
            shift
            ;;
        --install=*)
            INSTALL_DIR=${i#*=}
            shift
            ;;
        --install)
            shift
            INSTALL_DIR=$1
            shift
            ;;
        --spack=*)
            SPACK_DIR=${i#*=}
            shift
            ;;
        --spack)
            shift
            SPACK_DIR=$1
            shift
            ;;
        --overwrite)
            OVERWRITE=true
            shift
            ;;
        --split)
            SPLIT=true
            shift
            ;;
        --partitions=*)
            PARTITIONLIST=$(tr ',' ' ' <<<${i#*=})
            shift
            ;;
        --partitions)
            shift
            PARTITIONLIST=$(tr ',' ' ' <<<$1)
            shift
            ;;
        --nodes=*)
            NODELIST=$(tr ',' '\n' <<<${i#*=})
            PARTITIONLIST=$(sed -E 's/([0-9]+)//g' <<<$NODELIST | uniq | xargs)
            shift
            ;;
        --nodes)
            shift
            NODELIST=$(tr ',' '\n' <<<$1)
            PARTITIONLIST=$(sed -E 's/([0-9]+)//g' <<<$NODELIST | uniq | xargs)
            shift
            ;;
        --local)
            INSTALL_DIR=/scratch/$USER/.installs
            SPACK_DIR=/scratch/$USER/.spack
            LOCAL=true
            shift
            ;;
        --*)
            echo "ERROR: Unknown long option '$i'"
            echo
            echo "USAGE:"
            usage
            exit 1
            ;;
        -*)
            options=$(sed 's/./& /g' <<<${i#-})
            for letter in $options; do
                case $letter in
                    d)
                        DRY=echo
                        ;;
                    u)
                        git pull
                        ;;
                    i)
                        shift
                        INSTALL_DIR=$1
                        ;;
                    o)
                        OVERWRITE=true
                        ;;
                    s)
                        SPLIT=true
                        ;;
                    p)
                        shift
                        PARTITIONLIST=$(tr ',' ' ' <<<$1)
                        ;;
                    n)
                        shift
                        NODELIST=$(tr ',' '\n' <<<$1)
                        PARTITIONLIST=$(sed -E 's/([0-9]+)//g' <<<$NODELIST | uniq | xargs)
                        ;;
                    l)
                        INSTALL_DIR=/scratch/$USER/.installs
                        SPACK_DIR=/scratch/$USER/.spack
                        LOCAL=true
                        ;;
                    *)
                        echo "ERROR: Unknown short option '-${letter}'"
                        echo
                        echo "USAGE:"
                        usage
                        exit 1
                        ;;
                esac
            done
            shift
            ;;
    esac
done

# directory with needed dependencies installed
INSTALL_DIR=${INSTALL_DIR:-$HOME/Installs/spack}

# the experiment id
EXPERIMENT_ID=$1

# the work (repo) dir
REPO_DIR=${2:-$PWD}

# default run partition
PARTITIONLIST=${PARTITIONLIST:-cei}

# local install boolean
LOCAL=${LOCAL:-false}

# the split plan boolean
SPLIT=${SPLIT:-false}

# overwrite the packages?
OVERWRITE=${OVERWRITE:-false}

# the path to the spack installation
SPACK_DIR=${SPACK_DIR:-$HOME/spack-erad}

if [[ $REPO_DIR != /* ]]; then
    echo "ERROR: Path to repository is not absolute, please use the absolute path..."
    exit 2
fi

if [[ $INSTALL_DIR != /* ]]; then
    echo "ERROR: Path to installation dir is not absolute, please use the absolute path..."
    exit 2
fi

if [[ $SPACK_DIR != /* ]]; then
    echo "ERROR: Path to spack isn't absolute, please use the absolute path..."
    exit 2
fi

EXP_DIR=$(find $REPO_DIR -type d -path "*/experiments/$EXPERIMENT_ID")
if [ ! -n "$EXP_DIR" ]; then
    echo "ERROR: There isn't any experiment with this ID..."
    exit 3
fi

pushd $REPO_DIR

for partition in $PARTITIONLIST; do
    # lets install all needed dependencies first
    echo "-> Launching dependency installing job for partition $partition!"
    if [ $LOCAL != true ]; then
        INSTALL_DIR+=/$partition # as we are not running locally
        ${DRY:-} sbatch \
            -p ${partition} \
            -N 1 \
            -J dependencies_${EXPERIMENT_ID}_${partition} \
            -W \
            $(dirname $EXP_DIR)/deps.sh $INSTALL_DIR $EXP_DIR $SPACK_DIR $OVERWRITE
        echo
    fi
    echo "... and done!"
    echo

    # change the gppd-info to sinfo when porting
    ALLNODES=$(gppd-info --long --Node -S NODELIST -p $partition -h | awk '{print $1}')
    if [ -z ${NODELIST+x} ]; then
        nodes=$(paste -s -d" " - <<<$ALLNODES)
    else
        nodes=$(grep "$NODELIST" <<<$ALLNODES | paste -s -d" " -)
    fi

    # splits the plan if we were told to
    if [ $SPLIT = true ]; then
        num_nodes=$(wc -w <<<$nodes)
        ${DRY:-} rm -f $EXP_DIR/runs.plan.${partition}.*
        ${DRY:-} split -n l/$num_nodes -d -a 1 $EXP_DIR/runs.plan $EXP_DIR/runs.plan.${partition}.
    fi

    # counter to access the correct plan
    plan_part=${num_nodes:+0}

    for node in $nodes; do
        # if we are in local mode, install dependencies for this node
        if [ $LOCAL = true ]; then
            echo "Launching installation job locally for node ${node}..."
            ${DRY:-} sbatch \
                -p ${partition} \
                -w ${node} \
                -J dependencies_${EXPERIMENT_ID}_${node} \
                $(dirname $EXP_DIR)/deps.sh $INSTALL_DIR $EXP_DIR $SPACK_DIR $OVERWRITE
        fi

        # launch the slurm script for this node
        echo "Launching job for node ${node}..."
        ${DRY:-} sbatch \
            -p ${partition} \
            -w ${node} \
            -J qr_analysis_${EXPERIMENT_ID} \
            $EXP_DIR/exp.slurm $EXPERIMENT_ID $EXP_DIR $INSTALL_DIR ${plan_part:-}

        if [ ! -z ${plan_part:+z} ]; then
            plan_part=$((plan_part+1))
        fi
    done

    # revert the path so we can repeat to the next partition
    $INSTALL_DIR=$(dirname $INSTALL_DIR)

    echo
done

popd
