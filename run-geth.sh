#!/bin/bash

address_qty=0

simple_start () {
    
    echo '{
        "config": {
            "chainId": 15,
            "homesteadBlock": 0,
            "eip155Block": 0,
            "eip158Block": 0
        },
        "difficulty": "200000000",
        "gasLimit": "2100000",
        "alloc": {
            "7df9a875a174b3bc565e6424a0050ebc1b2d1d82": { "balance": "100000000000000000000000" },
            "f41c74c9ae680c1aa78f42e5647a62f353b7bdde": { "balance": "100000000000000000000000" },
            "f41c74c9ae680c1aa78f42e5647a62f353b7bdde": { "balance": "100000000000000000000000" },
            "f41c74c9ae680c1aa78f42e5647a62f353b7bdde": { "balance": "100000000000000000000000" },
            "f41c74c9ae680c1aa78f42e5647a62f353b7bdde": { "balance": "100000000000000000000000" },
        }
    }' > $HOME/ethereum:/root/genesis.json

    docker run -d --name ethereum-node -v $HOME/ethereum:/root \
            -p 8545:8545 -p 30303:30303 \
            ethereum/client-go --dev --rpcapi="db,eth,net,web3,personal,web3" --rpc --rpcaddr '0.0.0.0' \
            --dev.period 5 --rpcport 8545 --ws \
            --wsaddr '0.0.0.0' --wsport 8545 --cache 4096
}

start_multiple () {
    address_qty=$(echo $1 | sed -E s/[^0-9]//g)
    
    echo "Number of ETH accounts: $address_qty"

    if [ $address_qty -lt 1 ]
    then
        echo "Invalid accounts number"
        exit 1
    fi

    echo "Starting ethereum node..."
    simple_start

    eth_node_id=$(bash pure-start.sh --get-eth-node-id)
    sleep 10

    echo "Creating $address_qty additional ETH addresses..."

    address_list=$(
        docker exec -it "$eth_node_id" geth attach http://127.0.0.1:8545 \
            --exec  "(function a(i, r) { if (i==$address_qty) { return r } r.push(personal.newAccount('1')); return a(i+1, r) })(0, [])"
    )

    echo "Fetched addresses"
    
    echo "Address list: $address_list"
}

# trap 'echo "Terminating environment..."; bash pure-start.sh --shutdown' SIGINT

main () {

    if [ -z "$1" ]
    then
        simple_start
        exit 0
    fi

    while [ -n "$1" ]
    do
        case "$1" in
            --simple) simple_start ;;
            --start-*) start_multiple $1 ;;
        esac
        shift
    done
}

main $@
