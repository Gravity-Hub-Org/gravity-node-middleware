#!/bin/bash

ghnode_tag='gh-node'
ghnode_waves_tag='gh-node-waves'
ledgernode_tag='ledger-node'
ledgernodes_qty=5
volumes_root=''

ledgers_disabled=0
eth_node_conf_disabled=0

# overriden params
waves_node_url=''

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

rpc_urls=()
p2p_urls=()
configure_ledger_nodes () {
    # Building only once
    pub_keys=()
    address_list=()
    ledger_ids=()
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
      # DEBUG:
      # docker build --no-cache -f ledgernode.dockerfile -t "$image_name" .
      docker build -f ledgernode.dockerfile -t "$image_name" .

      volume_name=$(printf "%s-volume-%s" $ledgernode_tag $i)
      volume_list[i]=$volume_name

      docker volume create "$volume_name"
    
      # local ledger_id=$(docker run -d -v "$HOME/$volume_name:/proof-of-concept" "$image_name")
      # local ledger_id=$(docker run -d -v "$HOME/$volume_name:/proof-of-concept" "$image_name")
      local ledger_id=$(
          docker run -d \
          --mount source=$volume_name,destination=$HOME/$volume_name "$image_name"
      )

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

    if [ $eth_node_conf_disabled -eq 0 ]; then
      bash run-geth.sh

      sleep 15
    fi

    if [ $ledgers_disabled -eq 0 ]; then
      sleep 3
      configure_ledger_nodes 
      sleep 5
    fi

    eth_address="0x05554B4434492173957121f790dcb0f112bC5A12"
    # grab first geth node network interface
    eth_node_ip=$(get_ethereum_node_ip_address)

    echo "ETH Address: $eth_address"
    echo "ETH Node IP: $eth_node_ip"

    docker build -f ghnode.dockerfile \
         --build-arg ETH_ADDRESS=$eth_address \
         --build-arg NODE_URL="http://$eth_node_ip:8545" \
         --build-arg LEDGER_URL="${rpc_urls[0]}" \
         --build-arg ETH_NETWORK=$eth_node_ip -t "$ghnode_tag:1" .

    docker build -f ./waves-docker-image/Dockerfile -t waves/node .

    docker build -f ghnode-waves.dockerfile \
         --build-arg NODE_URL="http://$waves_node_ip:6869" \
         --build-arg LEDGER_URL="${rpc_urls[0]}" \
         -t "$ghnode_waves_tag:1" .

    echo "Start waves node..."

    local waves_node_cont=$(docker run -d --name waves-private-node -p 6869:6869 waves/node)
    # override
    waves_node_ip=$(get_container_ip "$waves_node_cont")
 
    cd ./proof-of-concept/contracts/waves

    if ! [ -x "$(command -v surfboard)" ]; then
        echo 'Error: surfboard is not installed.' >&2
    else
        surfboard test 
    fi

    
    docker run -d -p 26668:26657 "$ghnode_waves_tag:1"

    docker run -d -p 26669:26657 "$ghnode_tag:1"
}

shutdown_environment () {
    # eth_node_id=$(get_ethereum_node_cont_id)

    # docker stop $eth_node_id
    # docker rm $eth_node_id
    echo "Shutting down all ledger nodes..."
    docker ps -a | grep "$ledgernode_tag" | awk '{ print $1 }' | xargs -L1 docker stop  

    echo "Dropping all ledger nodes..."
    docker ps -a | grep "$ledgernode_tag" | awk '{ print $1 }' | xargs -L1 docker rm

    echo "Shutting down all gh nodes..."
    docker ps -a | grep "$ghnode_tag" |  awk '{ print $1 }' | xargs -L1 docker stop  

    echo "Dropping all gh nodes..."
    docker ps -a | grep "$ghnode_tag"  awk '{ print $1 }' | xargs -L1 docker stop  
}

# Sig kill handler
trap 'echo "Terminating environment..."; shutdown_environment' SIGINT

main () {
    while [ -n "$1" ]
    do
        case "$1" in
	    # variables
	    --ledger-qty) ledgernodes_qty=$2 ;;
            --no-ledger) ledgers_disabled=1 ;;
            --no-eth) eth_node_conf_disabled=1 ;;

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
