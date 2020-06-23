FROM golang:1.14-buster as gh-node

WORKDIR /app

COPY /proof-of-concept/ /app/

ENV DEBIAN_FRONTEND noninteractive

# Set args
ARG ETH_NETWORK=0.0.0.0
ARG ETH_ADDRESS=idk
# DO NOT CHANGE NEBULA_ADDRESS
ARG NEBULA_ADDRESS=0
ARG LEDGER_URL=idk
ARG NODE_URL=http://127.0.0.1:8545
ARG RUN_KEY='fc7f145547d4e4dba155cc8f3b77b447c68a0afb4203c91a5a99bea9f4339690'

# Deps
RUN apt-get install bash
# if nebula address is not 0, install deps
RUN bash ./gh-node/deps.sh -i $NEBULA_ADDRESS

RUN cd ./contracts/ethereum && \
    bash patcher.sh --nebula $NEBULA_ADDRESS --eth-network $ETH_NETWORK --eth-address $ETH_ADDRESS && \
    cat ./migrations/2_initial_contracts.js && \
    cat truffle-config.js && sleep 1 && \
    truffle migrate --network external | tee migration.txt; exit 0

RUN cd ./contracts/ethereum && cat migration.txt | bash address-extractor.sh >> nebula-address.txt

RUN echo 1 && export RUNTIME_NEBULA_ADDRESS=$(cat ./contracts/ethereum/nebula-address.txt | tail -c +3) && \
    cd ./gh-node && \
    export RUNTIME_NEBULA_ADDRESS=$(bash -c "if [ $NEBULA_ADDRESS = 0 ]; then echo $RUNTIME_NEBULA_ADDRESS; else echo $NEBULA_ADDRESS; fi") && \
    echo "Nebula address: $RUNTIME_NEBULA_ADDRESS" && \
    rm config.json && \
    bash build-conf.sh --nebula $RUNTIME_NEBULA_ADDRESS --node-url $NODE_URL \
       --native-url $LEDGER_URL --tcp-priv-key "$RUN_KEY" && \ 
    echo "CONFIG" && cat config.json

ENTRYPOINT ./gh-node/gh-node --config "$PWD/gh-node/config.json"
