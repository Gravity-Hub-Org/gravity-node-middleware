FROM golang:1.14-alpine as gh-node

WORKDIR /app

COPY /proof-of-concept/gh-node /app/gh-node
COPY /proof-of-concept/contracts /app/contracts

RUN apk add npm
RUN npm i -g --unsafe-perm=true --allow-root truffle

ARG ETH_NETWORK=0.0.0.0
ARG ETH_ADDRESS=idk
RUN cd ./contracts/ethereum && \
    ls -la && \
    /bin/sh patcher.sh --eth-network $ETH_NETWORK --eth-address $ETH_ADDRESS && \
    cat truffle-config.js && sleep 1 && \
    truffle migrate --network external

RUN cd ./gh-node && \
    ./build-conf.sh --nebula "NEBULA_ADDRESS" && \
    go build

ENTRYPOINT [ "./gh-node" ]