FROM tendermint/tendermint:latest as tendermint

USER root
WORKDIR /var/www/tendermint

RUN chmod -R 777 .
RUN tendermint init --home .

FROM golang:1.14-buster as ledger-node

USER root

WORKDIR /proof-of-concept

COPY /proof-of-concept /proof-of-concept
COPY tendermint-template.toml /proof-of-concept/tendermint-template.toml
COPY --from=tendermint /var/www/tendermint /proof-of-concept/ledger-node/data

ARG ETH_NODE_URL="http://localhost:8545"
ARG WAVES_NODE_URL="https://nodes-stagenet.wavesnodes.com"

RUN printf "ethNodeUrl = \"$ETH_NODE_URL\"\nwavesNodeUrl = \"$WAVES_NODE_URL\"\n" >> tendermint-template.toml && \
    cat tendermint-template.toml > ./ledger-node/data/config/config.toml

RUN apt-get update && \
    apt-get -y install gcc mono-mcs
    # rm -rf /var/lib/apt/lists/*

RUN cd ledger-node && ls -la && ls -la ./data/config/
RUN cd ledger-node && go build && chmod +x ledger-node

ENTRYPOINT ./ledger-node/ledger-node