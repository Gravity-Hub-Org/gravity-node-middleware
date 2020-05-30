FROM tendermint/tendermint:latest as tendermint

WORKDIR /var/www/tendermint
RUN tendermint init

FROM golang:1.14-alpine as ledger-node

WORKDIR /proof-of-concept

COPY /proof-of-concept /proof-of-concept
COPY --from=tendermint /var/www/tendermint /proof-of-concept/ledger-node/data
 
ARG ETH_NODE_URL="http://localhost:8545" 
ARG WAVES_NODE_URL="https://nodes-stagenet.wavesnodes.com"

RUN printf $(cat tendermint-template.toml) $ETH_NODE_URL $WAVES_NODE_URL >  tendermint-template.toml
COPY tendermint-config.toml /proof-of-concept/ledger-node/data/config/config.toml

RUN apk add build-base
RUN cd ledger-node && go build

ENTRYPOINT [ "./ledger-node" ]