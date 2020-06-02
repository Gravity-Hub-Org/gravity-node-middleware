#!/bin/bash

geth_node_image_id='ethereum/client-go'
geth_node_container_network='localhost'
geth_node_container_port='8545'

get_geth_address () {
    process_line=$(docker ps -a | grep "$geth_node_image_id")
    docker_container_id=$(echo "$process_line" | awk '{ print $1 }')

    eth_first_address=$(
        docker exec "$docker_container_id" \
        geth attach "http://$geth_node_container_network:$geth_node_container_port" --exec "eth.accounts[0]" | \
        tail -c +2 | head -c -2
    )

    echo "$eth_first_address"
}

while [ -n "$1" ]
do
    case "$1" in
        # firstly we initiate variables
        --image) geth_node_image_id=$2 ;;
        --cont-net) geth_node_container_network=$2 ;;
        --cont-port) geth_node_container_port=$2 ;;

        # handle functions
        --node-address) get_geth_address ;;
    esac
    shift
done