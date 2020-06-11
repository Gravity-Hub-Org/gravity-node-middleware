FROM tendermint/tendermint:latest as tendermint

USER root
WORKDIR /var/www/tendermint

RUN chmod -R 777 .
RUN tendermint init --home /proof-of-concept/ledger-node/data/

FROM golang:1.14-buster as ledger-node

USER root

WORKDIR /proof-of-concept

ARG VALIDATOR_INDEX=0
ARG ETH_NODE_URL="http://localhost:8545"
ARG WAVES_NODE_URL="https://nodes-stagenet.wavesnodes.com"

COPY /proof-of-concept /proof-of-concept

COPY toml-patcher.sh /proof-of-concept/toml-patcher.sh
COPY toml-patcher.sh /proof-of-concept/toml-patcher.sh
COPY pure-start.sh /proof-of-concept/pure-start.sh

COPY tendermint-template.toml /proof-of-concept/tendermint-template.toml
COPY --from=tendermint /var/www/tendermint /proof-of-concept/ledger-node/data

RUN bash toml-patcher.sh -i tendermint-template.toml -o config.toml \
    --pairs "ethNodeUrl;${ETH_NODE_URL},wavesNodeUrl;${WAVES_NODE_URL}"

COPY ./ledger-config/genesis.json ./ledger-node/data/config/genesis.json
COPY ./ledger-config/priv_validator_key_${VALIDATOR_INDEX}.json ./ledger-node/data/config/priv_validator_key.json
RUN mv config.toml ./ledger-node/data/config/

RUN apt-get update && \
    apt-get -y install gcc mono-mcs

RUN cd ledger-node && ls -la && ls -la ./data/config/
RUN cd ledger-node && go build && chmod +x ledger-node

ENTRYPOINT cd ledger-node && ./ledger-node --config "$PWD/data/config/config.toml"