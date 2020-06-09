#!/bin/bash

delim=';'
input_file=''
out_file=''
pairs=''
temp_file='.toml-patch'

# sed "s/ethNodeUrl/$(echo 'ethNodeUrl = "https://127.0.0.1:8545"' | sed -e 's/[\/&]/\\&/g')/" tendermint-template.toml

auto_escape() {
  echo $1 | sed -e 's/[\/&]/\\&/g'
}

substitute_params () {
  cat "$input_file" > "$temp_file"

  IFS=','
  for pair in $pairs
  do
    local key=$(echo $pair | cut -d "$delim" -f1)
    local val=$(echo $pair | cut -d "$delim" -f2)
    key=$(auto_escape $key)
    val=$(auto_escape $val)

    echo "K: $key, V: $val"

    sed "s/$key/$key=\"$val\"/" "$temp_file" > "$out_file"
    cat "$out_file" > "$temp_file"
  done

  cat "$temp_file" > "$out_file"
  rm $temp_file
}

main() {

  while [ -n "$1" ]
  do
    case "$1" in
      # vars
      -de) delim=$2 ;;
      -i) input_file=$2 ;;
      -o) out_file=$2 ;;

      --pairs) pairs=$2 ;;
    esac
    shift
  done

  substitute_params
}

main $@