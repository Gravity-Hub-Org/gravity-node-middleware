FROM golang:1.14-alpine as gh-node

WORKDIR /app

COPY /proof-of-concept/gh-node /app/gh-node
COPY /proof-of-concept/contracts /app/contracts

RUN apk add npm
RUN npm i -g --allow-root truffle

RUN cd ./contracts/ethereum && \
    ls -la && \
    ./patcher --eth-address $ETH_ADDRESS && \
    truffle migrate --network external

RUN cd ./gh-node && \
    ./build-conf.sh --nebula "NEBULA_ADDRESS" && \
    go build

ENTRYPOINT [ "./gh-node" ]