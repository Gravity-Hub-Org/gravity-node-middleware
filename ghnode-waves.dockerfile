FROM golang:1.14-buster as gh-node

WORKDIR /app

COPY /proof-of-concept/ /app/

ENV DEBIAN_FRONTEND noninteractive

# Deps
RUN apt-get install bash
RUN curl -sL https://deb.nodesource.com/setup_14.x | bash -
RUN apt-get install -y nodejs && curl -L https://npmjs.org/install.sh | sh
RUN apt-get update && \
    apt-get -y install gcc mono-mcs && \
    rm -rf /var/lib/apt/lists/*
RUN npm i -g --unsafe-perm=true --allow-root @waves/surfboard

# Set args
ARG KEY=""

RUN cd ./contracts/waves && \
    surfboard test test/deploy.js && \
    bash build-conf-waves.sh  && \
    go build

ENTRYPOINT cd gh-node && ./gh-node --config "$PWD/config-waves.json" --key $KEY
