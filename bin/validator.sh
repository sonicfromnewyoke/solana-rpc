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
    # Since v4.1 the validator needs 26 ports, so the range must be at least 26 wide
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
    # Number of threads to use for replay of blocks on different forks (max 4)
    --replay-forks-threads 4
    # Number of threads to use for transaction replay (~ physical cores)
    --replay-transactions-threads 16
    # Transaction execution threads for the unified scheduler (cores/2).
    # unified-scheduler is the only (and default) block verification method since v4.0
    --unified-scheduler-handler-threads 8
    # Number of threads for TPU transaction receive
    --tpu-transaction-receive-threads 2
    # Number of threads for TVU shred receive
    --tvu-receive-threads 4
    # Number of threads for shred signature verification (~ physical cores/2)
    --tvu-shred-sigverify-threads 8
)

POH=(
    # Pin the PoH thread to this CPU core. Since v4.2 the default on Linux is core 0,
    # so always set it explicitly to your isolated core (see README "Isolate one core for PoH")
    --poh-pinned-cpu-core 10
)

XDP=(
    # XDP transmit is enabled by default since v4.2 (SKB / copy mode) and needs
    # CAP_NET_ADMIN + CAP_NET_RAW. Pass --no-xdp to fall back to plain UDP sockets.
    # Zero copy mode additionally needs CAP_BPF + CAP_PERFMON and NIC driver support
    --xdp-zero-copy
    # CPU cores reserved for XDP transmit. Must NOT overlap the PoH core (hard error).
    # If omitted, one core is auto-selected
    --xdp-cpu-cores 1
    # Network interface used for XDP transmit. Auto-detected from the default route if omitted
    --xdp-interface eth0
)

LEDGER=(
    # Number of threads for background accounts hashing/shrink (cores/4)
    --accounts-db-background-threads 4
    # Number of threads for foreground account operations (~ physical cores)
    --accounts-db-foreground-threads 16
    # Use DIR as ledger location [default: ledger]
    --ledger /mnt/ledger
    # Comma separated persistent accounts location. May be specified multiple times. [default: <LEDGER>/accounts]
    --accounts /mnt/accounts
    # Keep this amount of shreds in root slots.
    --limit-ledger-size 50000000
    # Mode to recovery the ledger db write ahead log.
    # [possible values: tolerate_corrupted_tail_records, absolute_consistency, point_in_time, skip_any_corrupted_record]
    --wal-recovery-mode skip_any_corrupted_record
    # Skip ledger verification at startup for faster catchup start
    --skip-startup-ledger-verification
    # Number of threads for RocksDB compaction (~ physical cores/2)
    --rocksdb-compaction-threads 8
    # Number of threads for RocksDB memtable flush (cores/4)
    --rocksdb-flush-threads 4
    # lz4 compression reduces ledger I/O with minimal CPU overhead
    --rocksdb-ledger-compression lz4
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
    # [default: 4]. Since v4.2 incremental snapshots are taken every 200 slots by default
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

exec agave-validator \
    "${CONSENSUS[@]}" \
    "${GOSSIP[@]}" \
    "${RPC[@]}" \
    "${REPLAY[@]}" \
    "${POH[@]}" \
    "${XDP[@]}" \
    "${LEDGER[@]}" \
    "${SNAPSHOTS[@]}" \
    "${SNAPSHOT_SOURCE[@]}" \
    "${LOG[@]}" \
    "${REPORTING[@]}"
