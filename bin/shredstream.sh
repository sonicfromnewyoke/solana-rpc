#!/bin/bash

# NOTE: --dest-ip-ports must point at the validator's TVU port, NOT the gossip port (8001 in validator.sh).
# Find it with:
#   export LEDGER_DIR=/mnt/ledger; bash -c "$(curl -fsSL https://raw.githubusercontent.com/jito-labs/shredstream-proxy/master/scripts/get_tvu_port.sh)"
exec jito-shredstream-proxy shredstream \
    --block-engine-url https://ny.mainnet.block-engine.jito.wtf \
    --auth-keypair /home/sol/my_keypair.json \
    --desired-regions ny \
    --dest-ip-ports 127.0.0.1:8001
