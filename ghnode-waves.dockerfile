FROM golang:1.14-buster as gh-node

WORKDIR /app

COPY /proof-of-concept/ /app/

ENV DEBIAN_FRONTEND noninteractive

ARG NODE_URL="http://localhost:6869"
ARG LEDGER_URL="blank"

# Deps
RUN apt-get install bash
RUN curl -sL https://deb.nodesource.com/setup_14.x | bash -
RUN apt-get update && \
    apt-get -y install gcc mono-mcs && \
    rm -rf /var/lib/apt/lists/*

RUN cd ./gh-node && \
    bash build-conf-waves.sh --node-url $NODE_URL --native-url $LEDGER_URL && \
    go build

ENTRYPOINT cd gh-node && ./gh-node --key "waves private node seed with waves tokens1" --config "config-waves.json"
