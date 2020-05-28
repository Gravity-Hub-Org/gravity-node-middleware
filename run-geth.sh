#!/bin/bash

docker run -d --name ethereum-node -v $HOME/ethereum:/root \
           -p 8545:8545 -p 30303:30303 \
           ethereum/client-go --dev --rpc --rpcaddr '0.0.0.0' \
           --dev.period 5 --rpcport 8545 --ws \
            --wsaddr '0.0.0.0' --wsport 8545 --cache 4096