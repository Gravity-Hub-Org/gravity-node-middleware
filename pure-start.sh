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

trim_by_one () {
    echo $1 | head -c -2 | tail -c +2
}

get_validator_template() {
    printf '
    {
      "address": "%s",
      "pub_key": {
        "type": "tendermint/PubKeyEd25519",
        "value": "%s"
      },
      "power": "10",
      "name": ""
    }
    ' "$1" "$2"
}

configure_ledger_nodes () {
    # Building only once
    pub_keys=()
    address_list=()
    ledger_ids=()

    for ((i = 0; i<$ledgernodes_qty; i++))
    do
      local tag="1.$((i+1))"

      local image_name="$ledgernode_tag:$tag"
      docker build -f ledgernode.dockerfile -t "$image_name" .

      local ledger_id=$(docker run -d "$image_name")

      ledger_ids[i]=$ledger_id
      sleep 3

      local priv_key=$(docker exec -it "$ledger_id" cat ./ledger-node/data/config/priv_validator_key.json)

      pub_keys[i]=$(trim_by_one $(echo $priv_key | jq '.pub_key.value'))
      address_list[i]=$(trim_by_one $(echo $priv_key | jq '.address'))
    done

    local validators='[]'

    for ((j = 0; j<$ledgernodes_qty; j++))
    do
      local current_valid_obj=$(get_validator_template ${address_list[j]} ${pub_keys[j]})

      validators=$(echo $validators | jq ". + [$current_valid_obj]")
    done

    echo "Validator: $validators"
    echo "Pub keys: ${pub_keys[@]}"
    echo "Address list: ${address_list[@]}"


    for ((j = 0; j<$ledgernodes_qty; j++))
    do
      local ledger_id=${ledger_ids[j]}
      
      # update genesis.json
      docker exec -it "$ledger_id" ./ledger-node/data/config/genesis.json | jq ".validators = $validators"
      docker stop "$ledger_id"
      docker start "$ledger_id"
    done
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