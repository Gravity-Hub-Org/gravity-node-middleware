#!/bin/bash

address_qty=0

simple_start () {
    docker run -d --name ethereum-node -v $HOME/ethereum:/root \
            -p 8545:8545 -p 30303:30303 \
            ethereum/client-go --dev --rpcapi="db,eth,net,web3,personal,web3" --rpc --rpcaddr '0.0.0.0' \
            --dev.period 5 --rpcport 8545 --ws \
            --wsaddr '0.0.0.0' --wsport 8545 --cache 4096
}

#Account #1
#Address: 0x05554B4434492173957121f790dcb0f112bC5A12
#Private key: fc7f145547d4e4dba155cc8f3b77b447c68a0afb4203c91a5a99bea9f4339690

#Account #2
#Address: 0x4E5bf8Be72bfdb84A5a2A2f1d8Ac0D504183f20c
#Private key: 8786a6ab62cdaa05a2a0aece6c792933bf655fa73cf6a0957920a988a062bf77

#Account #3
#Address: 0x452cB7418c934b3A72Bc7F492E8Ff9CFE1a2FE17
#Private key: 065a30dc6473d1b81c588cfd959f0154a3b29eda9a3e5ad6fafe7d476f840a4e

#Account #4
#Address: 0xc120096945608b67e8A99eeD186c4ae1928F3cfF
#Private key: 4d6c82aa07cd6c75f16292d45ff1476eb852bf18e2b02f4b48be4149a5a14c2e

#Account #5
#Address: 0xc018A514A38d5fAA13C60FB57F831C823c12cce6
#Private key: 90275f0790c1692a7610be44bdf87e90e56abda8452c75bc376476a1e3a95cff

start_multiple () {
    address_qty=5
    
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


    address_list="['0x05554B4434492173957121f790dcb0f112bC5A12',
    '0x4E5bf8Be72bfdb84A5a2A2f1d8Ac0D504183f20c',
    '0x452cB7418c934b3A72Bc7F492E8Ff9CFE1a2FE17',
    '0xc120096945608b67e8A99eeD186c4ae1928F3cfF',
    '0xc018A514A38d5fAA13C60FB57F831C823c12cce6']"

    docker exec -it "$eth_node_id" geth attach http://127.0.0.1:8545 \
            --exec  "(function a(i, array) {
                if (i==$address_qty) { 
                    return array; 
                } 
                eth.sendTransaction({
                    from:  eth.accounts[0],
                    to: array[i],
                    value: web3.toWei(1000, 'ether')
                });
                return a(i+1, array) 
                })(0, $address_list)"
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
            --start) start_multiple ;;
        esac
        shift
    done
}

main $@
