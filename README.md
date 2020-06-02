
### Gravity Node Middleware

#### Deployment

#### Run ethereum node in dev mode
```
bash run-geth.sh
```

```
    docker build -f ghnode.dockerfile \
    --build-arg ETH_ADDRESS=0x836b7d8d0648c41d212ed19a242a8c91979689f6 \
    --build-arg ETH_NETWORK=172.17.0.2 -t gh-node:2 .
```

