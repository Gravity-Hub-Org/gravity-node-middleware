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

rpc_urls=()
p2p_urls=()
configure_ledger_nodes () {
    # Building only once
    ledger_ids=()
    volume_list=()
    pub_keys=()
    address_list=()

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
      docker build -f ledgernode.dockerfile \
        --build-arg ETH_NODE_URL=$1 \
        --build-arg WAVES_NODE_URL=$2 \
        --build-arg VALIDATOR_INDEX=$i \
        -t "$image_name" .

      volume_name=$(printf "%s-volume-%s" $ledgernode_tag $i)
      volume_list[i]=$volume_name

      docker volume create "$volume_name"
    
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

    for ((j = 0; j<$ledgernodes_qty; j++))
    do
        local current_valid_obj=$(get_validator_template ${address_list[j]} ${pub_keys[j]})
        local ledger_id=${ledger_ids[j]}
        # update rpc & p2p urls
        # cont_ip - just ip
        local cont_ip=$(get_container_ip $ledger_id)
        rpc_urls[j]="$cont_ip:$rpc_port"
        p2p_urls[j]="$cont_ip:$p2p_port"

      
        if [[ j -gt 0 ]]
        then
            seeds_list+=','
        fi

        seed_address=$(echo ${p2p_urls[j]})
        seeds_list+="\"${address_list[j]}@$seed_address\""

        validators=$(echo $validators | jq ". + [$current_valid_obj]")
    done

    for ((j = 0; j<$ledgernodes_qty; j++))
    do
      local ledger_id=${ledger_ids[j]}
      docker start "$ledger_id"
    done

    
    for ((j = 0; j<$ledgernodes_qty; j++))
    do
        url="${rpc_urls[j]}/dial_peers?persistent=true&peers=\[${seeds_list}\]"
        
        echo $url
        docker exec ${ledger_ids[j]} curl $url
    done
}

pure_start () {
    # start geth
    echo "Starting Ethereum node in dev mode..."
    echo "Please wait up to 15 sec..."

    if [ $eth_node_conf_disabled -eq 0 ]; then
      bash run-geth.sh
      sleep 15
    fi

    eth_node_ip=$(get_ethereum_node_ip_address)

    cd ./waves-image && docker build . -t waves-node && cd ..

    echo "Start waves node..."

    waves_node_cont=$(docker run -d --name waves-private-node -p 6869:6869 waves-node)
    # override
    waves_node_ip=$(get_container_ip "$waves_node_cont")
    
    sleep 10

    if [ $ledgers_disabled -eq 0 ]; then
      sleep 3
      configure_ledger_nodes "http://$eth_node_ip:8545" "http://$waves_node_ip:6869"
      sleep 5
    fi

    eth_address="0x05554B4434492173957121f790dcb0f112bC5A12"
    # grab first geth node network interface

    echo "ETH Address: $eth_address"
    echo "ETH Node IP: $eth_node_ip"

    docker build -f ghnode.dockerfile \
         --build-arg ETH_ADDRESS=$eth_address \
         --build-arg NODE_URL="http://$eth_node_ip:8545" \
         --build-arg LEDGER_URL="http://${rpc_urls[0]}" \
         --build-arg ETH_NETWORK=$eth_node_ip -t "$ghnode_tag:1" .

    docker build -f ghnode-waves.dockerfile \
         --build-arg NODE_URL="http://$waves_node_ip:6869" \
         --build-arg LEDGER_URL="http://${rpc_urls[0]}" \
         -t "$ghnode_waves_tag:1" .

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

drop_all_containers () {
    docker ps -a | awk '{ print $1 }' | xargs -L1 docker stop
    docker ps -a | awk '{ print $1 }' | xargs -L1 docker rm
}

# Sig kill handler
trap 'echo "Terminating environment..."; shutdown_environment; exit 0' SIGINT

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
         
            # distinct helpers
            --drop-all) drop_all_containers; exit 0 ;;
        esac
        shift
    done
}

main $@
