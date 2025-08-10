#!/bin/bash

set -e

if [ "$LKDE_DIR" = "" ]; then
    LKDE_DIR=$PWD
fi

info()
{
    echo " * LKDE_DIR=$LKDE_DIR"
    echo " * ENV=$ENV"
}

run_command()
{
    info
    echo " * command: $1"
    cd $LKDE_DIR
    $1
}

help()
{
    echo "lkde.sh usage:"
    echo ""
    echo "    set-lkde [string]   set the LKDE_DIR base directory"
    echo "    set-env  [string]   set the ENV variable"
    echo "    info                read the LKDE_DIR and ENV values"
    echo "    help                show help message"
    echo "    [string]            execute a command in the LKDE_DIR directory"
}

if [ "$1" = "help" ]; then
    help
elif [ "$1" = "set-lkde" ]; then
    export LKDE_DIR=$2
    echo "LKDE_DIR set to $LKDE_DIR. You are in a new shell."
    bash
elif [ "$1" = "set-env" ]; then
    export ENV=$2
    echo "ENV set to $ENV. You are in a new shell."
    bash
elif [ "$1" = "info" ]; then
    info
else
    run_command $1
fi
