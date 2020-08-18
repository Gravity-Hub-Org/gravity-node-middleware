FROM golang:1.14-buster as gh-node

WORKDIR /app

COPY /proof-of-concept/ /app/

ENV DEBIAN_FRONTEND noninteractive

ARG NODE_URL="http://localhost:6869"
ARG LEDGER_URL="blank"
ARG DEPLOY=1
ARG KEY=""
ENV SEED=$KEY
# Deps
RUN apt-get install bash
RUN echo "Installing dependencies" && export NODE_URL && bash ./gh-node/deps.sh -wi $DEPLOY; exit 0

RUN cd ./gh-node && \
    bash build-conf-waves.sh --priv-key $KEY --node-url $NODE_URL --native-url $LEDGER_URL && \
    echo "Config:" && cat config-waves.json

ENTRYPOINT cd gh-node && ./gh-node --config "config-waves.json"
