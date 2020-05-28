FROM tendermint/tendermint:latest as tendermint

WORKDIR /var/www/tendermint
RUN tendermint init

FROM golang:1.14-alpine as ledger-node

WORKDIR /proof-of-concept

COPY /proof-of-concept /proof-of-concept
COPY --from=tendermint /var/www/tendermint /proof-of-concept/ledger-node/data

COPY tendermint-config.toml /proof-of-concept/ledger-node/data/config/config.toml

RUN cd ledger-node && go build

ENTRYPOINT [ "./ledger-node" ]