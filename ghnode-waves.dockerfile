FROM golang:1.14-buster as gh-node

WORKDIR /app

COPY /proof-of-concept/ /app/

ENV DEBIAN_FRONTEND noninteractive

ARG NODE_URL="http://localhost:6869"
ARG LEDGER_URL="blank"
ARG KEY=""

# Deps
RUN apt-get install bash
RUN curl -sL https://deb.nodesource.com/setup_14.x | bash -
RUN apt-get install -y nodejs && curl -L https://npmjs.org/install.sh | sh
RUN apt-get update && \
    apt-get -y install gcc mono-mcs && \
    rm -rf /var/lib/apt/lists/* \
    npm install @waves/surfboard 

RUN npm i -g --unsafe-perm=true --allow-root @waves/surfboard
RUN cd ./contracts/waves && bash patch-surfboard.sh $NODE_URL surfboard.config.json
RUN cd ./contracts/waves && \
    surfboard test deploy.js

RUN cd ./gh-node && \
    bash build-conf-waves.sh --node-url $NODE_URL --native-url $LEDGER_URL && \
    go build

ENTRYPOINT cd gh-node && ./gh-node --key ${KEY} --config "config-waves.json"
