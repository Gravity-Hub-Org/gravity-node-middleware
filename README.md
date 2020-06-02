#  Gravity Node Middleware

##  Deployment

You can automatically start deploying the environment by calling:

```
bash pure-start.sh --simple
```

Or manually:

###  1. Run Ethereum node in dev mode

Run script and wait for couple of minutes for node to sync.
```
bash run-geth.sh
```
### 2.  Build Gravity node image

You should get ethereum node address and its network
  
####  Getting address:
Run script and you will get first address of `eth.account` array inside the geth node.
```
$ bash geth-helper.sh --node-address
0xba2ab90d58bf5b3fc8f9224c2d07e220dfa41ff0
```

You can also provide additional *overriding* params such as:

```
# --image <image_id> - Docker image ID
# --cont-net <int> - Node network IP
# --cont-port <int> - Node port
```

#### Start docker image build:

Regarding image building, *consider overriding*:
1) Image tag `-t <image_name:tag>`
2) `ETH_ADDRESS` must equal to the address of your node. (we extracted it above)
3) `ETH_NETWORK` must equal to `node IP address` in docker network.

```
docker build -f ghnode.dockerfile \
--build-arg ETH_ADDRESS=0x836b7d8d0648c41d212ed19a242a8c91979689f6 \
--build-arg ETH_NETWORK=172.17.0.2 -t gh-node:2 .

```