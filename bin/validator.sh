#!/bin/bash

# Use local snapshots if available to avoid re-downloading on restart.
# Falls back to network download on first boot or if snapshots are missing.
if compgen -G "/mnt/ledger/snapshot-*.tar.zst" > /dev/null 2>&1; then
    SNAPSHOT_SOURCE=(--no-snapshot-fetch)
else
    SNAPSHOT_SOURCE=()
fi

CONSENSUS=(
    # Validator identity keypair
    --identity /home/sol/validator-keypair.json
    # Launch validator without voting
    --no-voting
    # Require the genesis have this hash
    --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d
    # Skip the check for PoH speed
    --no-poh-speed-test
)

GOSSIP=(
    # Gossip port number for the validator
    --gossip-port 8001
    # Rendezvous with the cluster at this gossip entrypoint
    --entrypoint entrypoint.mainnet-beta.solana.com:8001
    --entrypoint entrypoint2.mainnet-beta.solana.com:8001
    --entrypoint entrypoint3.mainnet-beta.solana.com:8001
    --entrypoint entrypoint4.mainnet-beta.solana.com:8001
    --entrypoint entrypoint5.mainnet-beta.solana.com:8001
    # Do not perform TCP/UDP reachable port checks at start-up
    --no-port-check
)

RPC=(
    # Enable JSON RPC on this port, and the next port for the RPC websocket
    --rpc-port 8899
    # IP address to bind the RPC port [default: 127.0.0.1
    # if --private-rpc is present, otherwise use --bind-address]
    --rpc-bind-address 0.0.0.0
    # Range to use for dynamically assigned ports [default: 8000-10000]
    --dynamic-port-range 8000-8100
    # Expose RPC methods for querying chain state and transaction history
    --full-rpc-api
    # Do not publish the RPC port for use by others
    --private-rpc
    # The number of upcoming leaders to which to forward transactions sent via rpc service. [default: 2]
    --rpc-send-leader-count 3
    # Enable the unstable RPC PubSub `blockSubscribe` subscription
    --rpc-pubsub-enable-block-subscription
    # Enable historical transaction info over JSON RPC, including the 'getConfirmedBlock' API.
    # This will cause an increase in disk usage and IOPS
    --enable-rpc-transaction-history
    # Enable Geyser interface even if no Geyser configs are specified
    --geyser-plugin-always-enabled
)

REPLAY=(
    # Number of threads to use for replay of blocks on different forks
    --replay-forks-threads 4
    # Number of threads to use for transaction replay
    --replay-transactions-threads 8
)

POH=(
    # EXPERIMENTAL: Specify which CPU core PoH is pinned to
    --experimental-poh-pinned-cpu-core 10
)

RETRANSMIT=(
     # EXPERIMENTAL: Enable XDP zero copy for retransmit
    --experimental-retransmit-xdp-zero-copy
    # EXPERIMENTAL: Specify which CPU core XDP retransmit is pinned to
    --experimental-retransmit-xdp-cpu-cores 1
    # EXPERIMENTAL: The network interface to use for XDP retransmit
    --experimental-retransmit-xdp-interface eth0
)

LEDGER=(
    # Number of threads to use for background accounts hashing
    --accounts-db-background-threads 2
    # Use DIR as ledger location [default: ledger]
    --ledger /mnt/ledger
    # Comma separated persistent accounts location. May be specified multiple times. [default: <LEDGER>/accounts]
    --accounts /mnt/accounts
    # Keep this amount of shreds in root slots.
    --limit-ledger-size 50000000
    # Mode to recovery the ledger db write ahead log. 
    # [possible values: tolerate_corrupted_tail_records, absolute_consistency, point_in_time, skip_any_corrupted_record]
    --wal-recovery-mode skip_any_corrupted_record
)

SNAPSHOTS=(
    # Use DIR as the base location for snapshots. A subdirectory named "snapshots" will be created.
    # [default:--ledger value]
    --snapshots /mnt/ledger
    # The minimal speed of snapshot downloads measured in bytes/second. If the initial download speed falls below
    # this threshold, the system will retry the download against a different rpc node. [default: 10485760]
    --minimal-snapshot-download-speed 20971520
    # The maximum number of full snapshot archives to hold on to when purging older snapshots. [default: 2]
    --maximum-full-snapshots-to-retain 1
    # The maximum number of incremental snapshot archives to hold on to when purging older snapshots.
    # [default: 4]
    --maximum-incremental-snapshots-to-retain 2
)

LOG=(
    # Redirect logging to the specified file, '-' for standard error. Sending the SIGUSR1 signal to the validator
    # process will cause it to re-open the log file
    --log /home/sol/agave-validator.log
)

REPORTING=(
    # Disable reporting of OS network statistics
    --no-os-network-stats-reporting
    # Disable reporting of OS memory statistics
    --no-os-memory-stats-reporting
    # Disable reporting of OS CPU statistics
    --no-os-cpu-stats-reporting
    # Disable reporting of OS disk statistics
    --no-os-disk-stats-reporting
)

exec agave-validator ${CONSENSUS[@]} ${GOSSIP[@]} ${RPC[@]} ${REPLAY[@]} ${POH[@]} ${RETRANSMIT[@]} ${LEDGER[@]} ${SNAPSHOTS[@]} ${SNAPSHOT_SOURCE[@]} ${LOG[@]} ${REPORTING[@]}