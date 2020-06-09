#!/bin/bash

ghnode_tag='gh-node'
ledgernode_tag='ledger-node'
ledgernodes_qty=5

get_ethereum_node_cont_id () {
    echo $(docker ps -a | grep ethereum/client-go | awk '{ print $1 }')
}

get_ethereum_node_ip_address () {
    cont_id=$(get_ethereum_node_cont_id)
    echo $(docker exec $cont_id ifconfig | grep inet | head -n1 | awk '{ print $2 }' | cut -d: -f2)
}

configure_ledger_nodes () {
    # Building only once

    local image_name="$ledgernode_tag"
    docker build -f ledgernode.dockerfile -t "$image_name" .
    docker run ledger-node -v $HOME/ledger-node/:/proof-of-concept
    
    # for ((i = 0; i<$ledgernodes_qty; i++))
    # do
	# # local tag="1.$((i+1))"
    #     # local image_name="$ledgernode_tag:$tag"
    #     local tag=$((i+1))
	#     echo "Building ledger node #$tag"

    #     docker run $image_name 
    # done
}

pure_start () {
    # start geth
    echo "Starting Ethereum node in dev mode..."
    echo "Please wait up to 15 sec..."
    bash run-geth.sh

    sleep 12

    eth_address=$(bash geth-helper.sh --node-address)
    # grab first geth node network interface
    eth_node_ip=$(get_ethereum_node_ip_address)

    docker build -f ghnode.dockerfile \
        --build-arg ETH_ADDRESS=$eth_address \
        --build-arg ETH_NETWORK=$eth_node_ip -t "$ghnode_tag:1" .

    configure_ledger_nodes
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
	        # variables
	        --ledger-qty) ledgernodes_qty=$2 ;;

	        # operations
            --simple) pure_start ;;
            --conf-ledger) configure_ledger_nodes ;;
            --shutdown) shutdown_environment ;;

            # misc
            --get-eth-node-id) echo $(get_ethereum_node_cont_id) ;;
        esac
        shift
    done
}

main $@