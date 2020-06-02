#!/bin/bash

pure_start () {}

main () {
    while [ -n "$1" ]
    do
        case "$1" in
            *) pure_start ;;
        esac
        shift
    done
}

main $@