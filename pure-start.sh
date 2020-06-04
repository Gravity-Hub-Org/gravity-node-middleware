#!/bin/bash

get_ethereum_node_cont_id () {
    echo $(docker ps -a | grep ethereum/client-go | awk '{ print $1 }')
}

get_ethereum_node_ip_address () {
    cont_id=$(get_ethereum_node_cont_id)
    echo $(docker exec $cont_id ifconfig | grep inet | head -n1 | awk '{ print $2 }' | cut -d: -f2)
}

pure_start () {
    # start geth
    echo "Starting Ethereum node in dev mode..."
    echo "Please wait up to 15 sec..."
    bash run-geth.sh

    sleep 15

    eth_address=$(bash geth-helper.sh --node-address)
    # grab first geth node network interface
    eth_node_ip=$(get_ethereum_node_ip_address)

    docker build -f ghnode.dockerfile \
        --build-arg ETH_ADDRESS=$eth_address \
        --build-arg ETH_NETWORK=$eth_node_ip -t gh-node:2 .
}

shutdown_environment () {
    eth_node_id=$(get_ethereum_node_cont_id)

    docker stop $eth_node_id
    docker rm $eth_node_id
}

# Sig kill handler
trap 'echo "Terminating environment..."; shutdown_environment' SIGINT

main () {
    while [ -n "$1" ]
    do
        case "$1" in
            --simple) pure_start ;;
            --shutdown) shutdown_environment ;;

            # misc
            --get-eth-node-id) echo $(get_ethereum_node_cont_id) ;;
        esac
        shift
    done
}

main $@