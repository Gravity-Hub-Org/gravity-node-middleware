#!/usr/bin/env bash
sysctl -w vm.max_map_count=262144

docker-compose kill
docker-compose -f docker-compose.yml up -d --build
