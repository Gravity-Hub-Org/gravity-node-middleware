FROM golang:1.14-buster as gh-node

WORKDIR /app

COPY /proof-of-concept/ /app/

# Set aliases
RUN alias address-extractor="bash $PWD/contracts/ethereum/address-extractor.sh"
RUN alias truffle-patcher="bash $PWD/contracts/ethereum/patcher.sh"

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

RUN cd ./contracts/ethereum && \
    truffle-patcher --eth-network $ETH_NETWORK --eth-address $ETH_ADDRESS && \
    cat truffle-config.js && sleep 1 && \
    truffle migrate --network external >> migration.txt

RUN echo "Migration file: \n" && cat ./contracts/ethereum/migration.txt

RUN cd ./contracts/ethereum && cat migration.txt | address-extractor >> nebula-address.txt

RUN export NEBULA_ADDRESS=$(cat ./contracts/ethereum/nebula-address.txt) && \
    cd ./gh-node && ls -la && \
    echo "Nebula address: $NEBULA_ADDRESS" && \
    bash build-conf.sh --nebula $NEBULA_ADDRESS && \
    go build

ENTRYPOINT [ "./gh-node/gh-node" ]
