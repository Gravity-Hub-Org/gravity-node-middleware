FROM golang:1.14-buster as gh-node

WORKDIR /app

COPY /proof-of-concept/ /app/

ENV DEBIAN_FRONTEND noninteractive

# Deps
RUN apt-get install bash
RUN curl -sL https://deb.nodesource.com/setup_14.x | bash -
RUN apt-get install -y nodejs && curl -L https://npmjs.org/install.sh | sh
RUN apt-get update && \
    apt-get -y install gcc mono-mcs && \
    rm -rf /var/lib/apt/lists/*
RUN npm i -g --unsafe-perm=true --allow-root truffle

# Set args
ARG ETH_NETWORK=0.0.0.0
ARG ETH_ADDRESS=idk
ARG LEDGER_URL=idk
ARG NODE_URL=http://127.0.0.1:8545

RUN cd ./contracts/ethereum && \
    bash patcher.sh --eth-network $ETH_NETWORK --eth-address $ETH_ADDRESS && \
    cat truffle-config.js && sleep 1 && \
    truffle migrate --network external | tee migration.txt

RUN echo "Migration file: \n" && cat ./contracts/ethereum/migration.txt

RUN cd ./contracts/ethereum && cat migration.txt | bash address-extractor.sh >> nebula-address.txt

RUN export NEBULA_ADDRESS=$(cat ./contracts/ethereum/nebula-address.txt) && \
    cd ./gh-node && ls -la && \
    echo "Nebula address: $NEBULA_ADDRESS" && \
    rm config.json && \
    bash build-conf.sh --nebula $NEBULA_ADDRESS --node-url $NODE_URL \
       --native-url $LEDGER_URL && \ 
    echo "CONFIG" && cat config.json && \
    go build

ENTRYPOINT ./gh-node/gh-node --config "$PWD/gh-node/config.json" --key "0xfc7f145547d4e4dba155cc8f3b77b447c68a0afb4203c91a5a99bea9f4339690"
