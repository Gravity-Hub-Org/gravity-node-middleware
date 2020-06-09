#!/bin/bash

ghnode_tag='gh-node'
ledgernode_tag='ledger-node'
ledgernodes_qty=5
volumes_root=''

get_ethereum_node_cont_id () {
    echo $(docker ps -a | grep ethereum/client-go | awk '{ print $1 }')
}

get_current_env_ip () {
    echo $(ifconfig | grep inet | head -n1 | awk '{ print $2 }' | cut -d: -f2)
}

get_container_ip () {
    local cont_id=$1
    # echo $(docker exec $cont_id ifconfig | grep inet | head -n1 | awk '{ print $2 }' | cut -d: -f2)
    echo $(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $cont_id)
}

get_ethereum_node_ip_address () {
    cont_id=$(get_ethereum_node_cont_id)
    echo $(get_container_ip $cont_id)
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
    rpc_urls=()
    p2p_urls=()
    volume_list=()

    # the ports for communication
    rpc_port=26657
    p2p_port=26656

    # seeds for first ledger node
    seeds_list=''

    # drop all ledger-node images
    docker images | grep "$ledgernode_tag" | awk '{ print $3 }' | docker rmi -f

    # build image with appropriate tag
    for ((i = 0; i<$ledgernodes_qty; i++))
    do
      # local tag="1.$((i+1))"

      local image_name="$ledgernode_tag"
      # no cache for pure dir init
      # docker build -f ledgernode.dockerfile -t "$image_name" .

      volume_name=$(printf "%s-volume-%s" $ledgernode_tag $i)
      volume_list[i]=$volume_name

      docker volume create "$volume_name"
    
      # local ledger_id=$(docker run -d -v "$HOME/$volume_name:/proof-of-concept" "$image_name")
      # local ledger_id=$(docker run -d -v "$HOME/$volume_name:/proof-of-concept" "$image_name")
      local ledger_id=$(docker run -d --mount source=$volume_name,destination=$HOME/$volume_name "$image_name")

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

      local ledger_id=${ledger_ids[j]}
      # update rpc & p2p urls
      # cont_ip - just ip
      local cont_ip=$(get_container_ip $ledger_id)
      rpc_urls[j]="tcp://$cont_ip:$rpc_port"
      p2p_urls[j]="tcp://$cont_ip:$p2p_port"

      
      if [[ j -gt 0 ]]
      then
        seeds_list+=','
      fi

      seed_address=$(echo ${p2p_urls[j]} | sed 's/tcp:\/\///')
      seeds_list+="${address_list[j]}@$seed_address"

      validators=$(echo $validators | jq ". + [$current_valid_obj]")
    done

    echo "Validator: $validators"
    echo "Pub keys: ${pub_keys[@]}"
    echo "Address list: ${address_list[@]}"
    echo "RPC list: ${rpc_urls[@]}"
    echo "P2P list: ${p2p_urls[@]}"

    local config_dir_url='/ledger-node/data/config/'
    local genesis_file_url='/ledger-node/data/config/genesis.json'
    local toml_file_url='/ledger-node/data/config/config.toml'
    for ((j = 0; j<$ledgernodes_qty; j++))
    do
      local ledger_id=${ledger_ids[j]}
      
      # update genesis.json
      local template=$(echo ".validators = $(echo $validators)")

      # docker cp ./test.txt f72bd9786d59:/proof-of-concept      

      # docker exec "$ledger_id" cat "$genesis_file_url" | jq "$template" > "$genesis_file_url"
      # new_genesis=$(docker exec "$ledger_id" cat "$genesis_file_url" | jq "$template")

      # docker cp e09790e06ea4:/proof-of-concept/ledger-node/data/config/genesis.json I
      
      # get current genesis
      docker cp "$ledger_id:/proof-of-concept$genesis_file_url" ./current.json
      cat ./current.json | jq "$template" > current.json

      docker cp ./current.json "$ledger_id:/proof-of-concept/$genesis_file_url"
      docker exec "$ledger_id" cat ".$genesis_file_url"
      # rm temp.json
      
      echo "Node #$((j+1)) genesis.json updated"
      # docker exec -it "$ledger_id" cat "$genesis_file_url"
      # sed 's/seeds\ =\ \"\"/seeds\ =\"like\"/' tendermint-template.toml 

      # docker cp "$ledger_id:/proof-of-concept$toml_file_url" ./current.toml
      # sed 's/seeds\ =\ \"\"/seeds\ =\"like\"/' tendermint-template.toml > ./current.toml

      # echo "TOML" && cat ./current.toml
      # docker cp ./current.toml "$ledger_id:/proof-of-concept/$toml_file_url"

      # docker exec "$ledger_id" cat ".$toml_file_url"
      rm current.json     

      echo "Seeds: $seeds_list"
      # docker stop "$ledger_id"
      # docker start "$ledger_id"

      # setting seeds for first node
      if [[ j -eq 0 ]]
      then
         # sed 's/seeds\ =\ \"\"/seeds\ =\"dick\"/'
         local sed_temp=$(printf 's/seeds\ =\ \"\"/seeds\ =\"%s\"/' "$seeds_list")
         # docker exec "$ledger_id" sed "$sed_temp" "$toml_file_url" > "$toml_file_url"

         docker cp "$ledger_id:/proof-of-concept$toml_file_url" ./current.toml

         sed "$sed_temp" ./current.toml > ./config.toml
         # sed 's/seeds\ =\ \"\"/seeds\ =\"like\"/' tendermint-template.toml > ./current.toml

         echo "Apt toml" && cat ./config.toml
         docker cp ./config.toml "$ledger_id:/proof-of-concept/$toml_file_url"
         rm current.toml config.toml
      fi

      docker stop "$ledger_id"
    done

    # starting nodes from 1 to n 
    for ((j = 1; j<$ledgernodes_qty; j++))
    do
      local ledger_id=${ledger_ids[j]}
      docker start "$ledger_id"
    done
   
    # starting first node 
    docker start "${ledger_ids[0]}"
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
    # eth_node_id=$(get_ethereum_node_cont_id)

    # docker stop $eth_node_id
    # docker rm $eth_node_id
    echo "Shut down..."
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
            --get-current-ip) echo $(get_current_env_ip) ;;
        esac
        shift
    done
}

main $@
