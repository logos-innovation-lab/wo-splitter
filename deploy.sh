#!/bin/bash

source .env

forge script \
  script/Deploy.s.sol:DeployScript \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --verifier sourcify \
  -vvvv
