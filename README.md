<h1 align="center">Solana RPC</h1>

> [!NOTE]
> This repo contains steps to configure a **slightly** more performant RPC than a **regular** one

## 🤖 Server

### Requirements

[Solana Hardware Compatibility List](https://solanahcl.org/) can be found here

- **CPU**
  - `2.8GHz` base clock speed, or faster
  - `16` cores / `32` threads, or more
  - SHA extensions instruction support
  - AMD Gen 3 or newer
  - Intel Ice Lake or newer
  - Higher clock speed is preferable over more cores
  - AVX2 instruction support (to use official release binaries, self-compile otherwise)
  - Support for AVX512f is helpful
- **RAM** 
  - `256GB` or more (for account indexes)
  - Error Correction Code (ECC) memory is suggested
  - Motherboard with 512GB capacity suggested
- **Disk**
  - **Accounts:** `500GB`, or larger. High TBW (Total Bytes Written)
  - **Ledger:** `1TB` or larger. High TBW suggested
  - **Snapshots:** `250GB` or larger. High TBW suggested
  - **OS:** (Optional) `500GB`, or larger. SATA OK

Consider a larger ledger disk if longer transaction history is required

> [!CAUTION]
> Accounts and ledger **should not be** stored on the same disk

### Sol User

Create a new Ubuntu user, named `sol`, for running the validator:

```bash
sudo adduser sol
```

It is a best practice to always run your validator as a non-root user, like the `sol` user we just created.

### Ports Opening

Note: RPC port remains closed, only SSH and gossip ports are opened.

For new machines with UFW disabled:

1. Add OpenSSH first to prevent lockout if you don't have password access
2. Open required ports
3. Close RPC port

```bash
sudo ufw enable

sudo ufw allow 22/tcp
sudo ufw allow 20000/udp
sudo ufw allow 8000:8100/tcp
sudo ufw allow 8000:8100/udp

sudo ufw deny 8899/tcp
sudo ufw deny 8899/udp

sudo ufw reload
```

### Hard Drive Setup

On your Ubuntu computer make sure that you have at least `2TB` of disk space mounted. You can check disk space using the `df` command:

```bash
df -h
```

To see the hard disk devices that you have available, use the list block devices command:

```bash
lsblk -f
```

#### Drive Formatting: Ledger

Assuming you have an nvme drive that is not formatted, you will have to format the drive and then mount it.

For example, if your computer has a device located at `/dev/nvme0n1`, then you can format the drive with the command:

```bash
sudo mkfs -t xfs /dev/nvme0n1
```
For your computer, the device name and location may be different.

Next, check that you now have a UUID for that device:

```bash
lsblk -f
```

In the fourth column, next to your device name, you should see a string of letters and numbers that look like this: `6abd1aa5-8422-4b18-8058-11f821fd3967`. That is the UUID for the device

#### Mounting Your Drive: Ledger

So far we have created a formatted drive, but you do not have access to it until you mount it. Make a directory for mounting your drive:

```bash
sudo mkdir -p /mnt/ledger
```

Next, change the ownership of the directory to your sol user:

```bash
sudo chown -R sol:sol /mnt/ledger
```

Now you can mount the drive:

```bash
sudo mount -o noatime -o logbufs=0 -o nofail  /dev/nvme0n1 /mnt/ledger
```

#### Formatting And Mounting Drive: AccountsDB

You will also want to mount the accounts db on a separate hard drive. The process will be similar to the ledger example above.

Assuming you have device at `/dev/nvme1n1`, format the device and verify it exists:

```bash
sudo mkfs -t xfs /dev/nvme1n1
```

Then verify the UUID for the device exists:

```bash
lsblk -f
```

Create a directory for mounting:

```bash
sudo mkdir -p /mnt/accounts
```

Change the ownership of that directory:

```bash
sudo chown -R sol:sol /mnt/accounts
```

And lastly, mount the drive:

```bash
sudo mount -o noatime -o logbufs=0 -o nofail   /dev/nvme1n1 /mnt/accounts
```


#### Modify fstab

```bash
sudo vi /etc/fstab
```

should contains something similar

```
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>

...

UUID="03477038-6fa7-4de3-9ca6-4b0aef52bf42" /mnt/ledger xfs defaults,noatime,logbufs=8,largeio,inode64,allocsize=64m,nofail 0 0
UUID="68ff3738-f9f7-4423-a24c-68d989a2e496" /mnt/accounts xfs defaults,noatime,logbufs=8,largeio,inode64,allocsize=64m,nofail 0 0
```

To verify the mounts are active with correct options:

```bash
mount | grep -E 'ledger|accounts'
# or
findmnt /mnt/ledger /mnt/accounts
```

## 🌵 Agave Client

### Install rustc, cargo and rustfmt

```bash
curl https://sh.rustup.rs -sSf | sh
source $HOME/.cargo/env
rustup component add rustfmt
```

When building the master branch, please make sure you are using the latest stable rust version by running:

```bash
rustup update
rustup default nightly
rustup override set nightly
```

you may need to install libssl-dev, pkg-config, zlib1g-dev, protobuf etc.

```bash
sudo apt-get update
sudo apt-get install libssl-dev libudev-dev pkg-config zlib1g-dev llvm clang libclang-dev cmake make libprotobuf-dev protobuf-compiler lld
```

### Download the source code

```bash
git clone https://github.com/anza-xyz/agave.git
cd agave

# let's asume we would like to build v3.1.8 of validator
export TAG="v3.1.8" 
git switch tags/$TAG --detach
```

### Build

```bash
export RUSTFLAGS="-Clink-arg=-fuse-ld=lld -Ctarget-cpu=native"
./scripts/cargo-install-all.sh  --release-with-lto --validator-only .
export PATH=$PWD/bin:$PATH
```

## 🦾 System Tuning

### Set CPU Governor to `Performance`

```bash
echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

### Enable CPU Boost

With the governor set to `performance`, ensure CPU boost (Turbo Boost / Precision Boost) is also enabled — on some systems it is a separate knob:

```bash
cat /sys/devices/system/cpu/cpufreq/boost
echo 1 | sudo tee /sys/devices/system/cpu/cpufreq/boost
```

> [!NOTE]
> The GRUB parameter `amd_pstate=passive` allows boost to function on AMD CPUs. On Intel, boost is controlled via the `intel_pstate` driver and is enabled by default in performance mode.

### Disable THP (Transparent Huge Pages)

Linux transparent huge page (THP) support allows the kernel to automatically promote regular memory pages into huge pages.
Huge pages reduces TLB pressure, but THP support introduces latency spikes when pages are promoted into huge pages and when memory compaction is triggered.

```bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
```

### Disable KSM (Kernel Samepage Merging)

Linux kernel samepage merging (KSM) is a feature that de-duplicates memory pages that contains identical data.
The merging process needs to lock the page tables and issue TLB shootdowns, leading to unpredictable memory access latencies.
KSM only operates on memory pages that has been opted in to samepage merging using `madvise(...MADV_MERGEABLE)`.
If needed KSM can be disabled system wide by running the following command:

```bash
echo 0 > /sys/kernel/mm/ksm/run
```

### Disable automatic NUMA memory balancing

Linux supports automatic page fault based NUMA memory balancing and manual page migration of memory between NUMA nodes.
Migration of memory pages between NUMA nodes will cause TLB shootdowns and page faults for applications using the affected memory

```bash
echo 0 > /proc/sys/kernel/numa_balancing
```

### NVMe I/O Scheduler

For NVMe devices the kernel may default to `mq-deadline` or `bfq`, both of which add queueing latency. Set the scheduler to `none` (passthrough) so I/O goes directly to the NVMe queue:

```bash
echo none | sudo tee /sys/block/nvme*/queue/scheduler
```

Disable read-ahead — RocksDB and accounts access patterns are largely random, so prefetching wastes bandwidth:

```bash
echo 0 | sudo tee /sys/block/nvme*/queue/read_ahead_kb
```

Persist both across reboots with a udev rule:

```bash
sudo bash -c 'cat > /etc/udev/rules.d/60-nvme-scheduler.rules <<EOF
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/read_ahead_kb}="0"
EOF'
sudo udevadm control --reload-rules && sudo udevadm trigger
```

### Huge and Gigantic Pages

```bash
sudo mkdir -p /mnt/hugepages
sudo mount -t hugetlbfs -o pagesize=2097152,min_size=228589568 none /mnt/hugepages

sudo mkdir -p /mnt/gigantic
sudo mount -t hugetlbfs -o pagesize=1073741824,min_size=27917287424 none /mnt/gigantic

cat /proc/mounts | grep hugetlbfs
# none /mnt/hugepages hugetlbfs rw,seclabel,relatime,pagesize=2M,min_size=95124124 0 0
# none /mnt/gigantic hugetlbfs rw,seclabel,relatime,pagesize=1024M,min_size=540092137472 0 0
```

### Sysctl Tuning

```bash
sudo bash -c "cat >/etc/sysctl.d/21-agave-validator.conf <<EOF
# TCP Buffer Sizes (10k min, 87.38k default, 12M max)
net.ipv4.tcp_rmem=10240 87380 12582912
net.ipv4.tcp_wmem=10240 87380 12582912

# Increase UDP buffer sizes
net.core.rmem_default = 134217728
net.core.rmem_max = 134217728
net.core.wmem_default = 134217728
net.core.wmem_max = 134217728

# Connection backlog (critical for RPC node)
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# NIC receive queue (critical for QUIC/UDP)
net.core.netdev_max_backlog = 250000

# XDP ancillary buffer
net.core.optmem_max = 65536

# TCP Optimization
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_timestamps=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_moderate_rcvbuf=1

# Kernel Optimization
kernel.timer_migration=0
kernel.hung_task_timeout_secs=30
kernel.pid_max=49152
kernel.nmi_watchdog=0

# Virtual Memory Tuning
vm.swappiness=0
vm.max_map_count = 2000000
vm.stat_interval=10
vm.dirty_ratio=40
vm.dirty_background_ratio=10
vm.min_free_kbytes=3000000
vm.dirty_expire_centisecs=36000
vm.dirty_writeback_centisecs=3000
vm.dirtytime_expire_seconds=43200

# Increase number of allowed open file descriptors
fs.nr_open = 2000000

# Increase Sync interval (default is 3000)
fs.xfs.xfssyncd_centisecs = 10000
EOF"
```

```bash
sudo sysctl -p /etc/sysctl.d/21-agave-validator.conf
```

### Increase systemd and session file limits

Add

```ini
LimitNOFILE=2000000
LimitMEMLOCK=2000000000
```
to the `[Service]` section of your systemd service file, if you use one, otherwise add

```ini
DefaultLimitNOFILE=2000000
DefaultLimitMEMLOCK=2000000000
```

to the `[Manager]` section of `/etc/systemd/system.conf`.

```bash
sudo systemctl daemon-reload
```

```bash
sudo bash -c "cat >/etc/security/limits.d/90-solana-nofiles.conf <<EOF
# Increase process file descriptor count limit
* - nofile 2000000
# Increase memory locked limit (kB)
* - memlock 2000000
EOF"
```

### NIC Tuning

#### Disable `irqbalance`

The GRUB `irqaffinity=` parameter pins hardware interrupts away from the PoH core, but `irqbalance` runs as a service and periodically overrides manual IRQ assignments. Disable it:

```bash
sudo systemctl disable --now irqbalance
```

#### Increase NIC ring buffers and reduce interrupt coalescing

Default NIC ring buffers are small and interrupt coalescing adds latency. Tune with `ethtool` (replace `eth0` with your interface name):

```bash
ip link show
```
Look for the interface that has state UP. It'll typically be named `eth0`, `ens3`, `enp5s0`, `bond0`, etc. — the naming depends on the system.

```bash
# For just the name of the primary interface (the one with the default route):
ip route get 1.1.1.1 | awk '{print $5; exit}'
```

```bash
# Check current and maximum ring buffer sizes
ethtool -g eth0

# Increase RX/TX ring buffers to reduce packet drops under QUIC burst traffic
sudo ethtool -G eth0 rx 4096 tx 4096

# Disable adaptive coalescing and minimize interrupt delay for lower latency
sudo ethtool -C eth0 adaptive-rx off adaptive-tx off rx-usecs 0 tx-usecs 0
```

To persist across reboots, add these commands to a systemd `ExecStartPost` or a `/etc/networkd-dispatcher` script.

### Isolate one core for PoH

> [!NOTE]
> Many thanks for that guide to [ax | 1000x.sh](https://discord.com/channels/428295358100013066/811317327609856081/1257995317190852651)

find out the nearest available core. in most cases, it's core 2 (cores 0 and 1 are often used by the kernel). if you have more cores, you can choose another available nearest core.

#### Know your topology

```bash
lstopo
```

check your cores and hyperthreads
look at the "cores" table to find your core and its hyperthread. for example, if you choose core 10, its hyperthread might be 34 (in my case)

```bash
lscpu --all -e
```

the easiest way to find the hyperthread for eg core 10:

```bash
cat /sys/devices/system/cpu/cpu10/topology/thread_siblings_list
```

#### Isolate the core and its hyperthread

in my case the hyperthread for core 10 is 34
`/etc/default/grub` (don't forget to run update-grub and reboot afterwards) 

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_pstate=passive nvme_core.default_ps_max_latency_us=0 nohz_full=10,34 isolcpus=domain,managed_irq,10,34 irqaffinity=0-9,11-33,35-47"
```

```sh
update-grub
```

> [!NOTE]
> - `nohz_full=10,34` enables full dynamic ticks for core 10 and its hyperthread 34 to reducing overhead and latency.
> - `isolcpus=domain,managed_irq,10,34` isolates core 10 and hyperthread 34 from the general scheduler
> - `irqaffinity=0-9,11-33,25-47` directs interrupts away from core 10 and hyperthread 34 

#### Set the poh thread to core 10

add the cli to your validator

```
...
--experimental-poh-pinned-cpu-core 10 \ 
...
```

there is a bug with core_affinity if you isolate your cores: [link](https://github.com/anza-xyz/agave/issues/1968)

you can take the next bash script to identify the pid of solpohtickprod and set it to eg. core 10

```bash
#!/bin/bash

# main pid of agave-validator
agave_pid=$(pgrep -f "^agave-validator --identity")
if [ -z "$agave_pid" ]; then
    logger "set_affinity: agave_validator_404"
    exit 1
fi

# find thread id
thread_pid=$(ps -T -p $agave_pid -o spid,comm | grep 'solPohTickProd' | awk '{print $1}')
if [ -z "$thread_pid" ]; then
    logger "set_affinity: solPohTickProd_404"
    exit 1
fi

current_affinity=$(taskset -cp $thread_pid 2>&1 | awk '{print $NF}')
if [ "$current_affinity" == "10" ]; then
    logger "set_affinity: solPohTickProd_already_set"
    exit 1
else
    # set poh to cpu 10
    sudo taskset -cp 10 $thread_pid
    logger "set_affinity: set_done"
     # $thread_pid
fi
```

### XDP

your validator binary will need to have access to a few higher level permissions.  To give the minimal required set of privileges to the binary run the following command:

```bash
sudo setcap cap_net_raw,cap_bpf,cap_net_admin=p
```

## 🚀 Validator Startup

### Options

### Let's use the common one

```bash
mkdir -p /home/sol/bin
```

Next, open the [`validator.sh`](./bin/validator.sh) file for editing:

```bash
vi /home/sol/bin/validator.sh
```
Then

```bash
chmod +x /home/sol/bin/validator.sh
```

### Create a System Service

You can use the [`sol.service`](./system/sol.service) from this repo or `sudo vi /etc/systemd/system/sol.service` and paste

```ini
[Unit]
Description=Solana Validator
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
LimitNOFILE=2000000
LimitMEMLOCK=2000000000
LogRateLimitIntervalSec=0
User=sol
Environment="PATH=/home/sol/agave/bin"
Environment=SOLANA_METRICS_CONFIG=host=https://metrics.solana.com:8086,db=mainnet-beta,u=mainnet-beta_write,p=password
ExecStart=/home/sol/bin/validator.sh

[Install]
WantedBy=multi-user.target
```

### Setup log rotation

You can use the [`logrotate.sol`](./logrotate.sol) from this repo run the next commands

```bash
cat > logrotate.sol <<EOF
/home/sol/agave-validator.log {
  rotate 7
  daily
  missingok
  postrotate
    systemctl kill -s USR1 sol.service
  endscript
}
EOF

sudo cp logrotate.sol /etc/logrotate.d/sol
systemctl restart logrotate.service
```

The validator log file, as specified by `--log ~/agave-validator.log`, can get very large over time and it's recommended that log rotation be configured.

The validator will re-open its log file when it receives the `USR1` signal, which is the basic primitive that enables log rotation.

If the validator is being started by a wrapper shell script, it is important to launch the process with `exec` (`exec agave-validator ...`) when using logrotate. This will prevent the `USR1` signal from being sent to the script's process instead of the validator's, which will kill them both.

### Enable and start System Service

```bash
sudo systemctl enable --now sol
```

```bash
sudo systemctl status sol.service
```

### Restarting with Local Snapshots

Re-downloading a snapshot from the network on every restart wastes time. The `validator.sh` script automatically passes `--no-snapshot-fetch` when a local full snapshot is detected in `/mnt/ledger`, so you only need to ensure a fresh snapshot exists before stopping the service.

#### 1. Wait for a restart window and verify a snapshot is ready

```bash
agave-validator -l /mnt/ledger wait-for-restart-window --min-idle-time 2
```

This blocks until the validator is at least 2 minutes from being scheduled as a leader **and** a fresh full snapshot has been written to disk. It is the safest way to prepare for a restart.

> [!TIP]
> Add `--skip-new-snapshot-check` if you already have a recent snapshot and just want to find a quiet window without waiting for a new one to be generated.

#### 2. Confirm a snapshot exists

```bash
ls -lh /mnt/ledger/snapshot-*.tar.zst
```

You should see at least one file like `snapshot-<slot>-<hash>.tar.zst`.

#### 3. Restart the service

```bash
sudo systemctl restart sol
```

Because a `snapshot-*.tar.zst` file is present, `validator.sh` will start with `--no-snapshot-fetch` and use the local snapshot, cutting restart time down to a few minutes.

> [!NOTE]
> On a **fresh machine** (no local snapshots) the script falls back to downloading a snapshot from the network automatically — no manual intervention needed.

### Setup Shredstream Proxy

Jito’s ShredStream service delivers the lowest latency shreds from leaders on the Solana network, optimizing performance for high-frequency trading, validation, and RPC operations.
ShredStream ensures minimal latency for receiving shreds, which can save hundreds of milliseconds during trading on Solana—a critical advantage in high-frequency trading environments.
Additionally, it provides a redundant shred path for servers in remote locations, enhancing reliability and performance for users operating in less connected regions.
This makes ShredStream particularly valuable for traders, validators, and node operators who require the fastest and most reliable data to maintain a competitive edge.

#### Download the source code

```bash
git clone https://github.com/jito-labs/shredstream-proxy.git --recurse-submodules
cd shredstream-proxy
```

#### Build 

```bash
export RUSTFLAGS="-Clink-arg=-fuse-ld=lld -Ctarget-cpu=native"
cargo build --release --bin jito-shredstream-proxy

mkdir ./bin
cp target/release/jito-shredstream-proxy ./bin/jito-shredstream-proxy
export PATH=$PWD/bin:$PATH
```

#### Preparation

1. Get your Solana [public key approved](https://web.miniextensions.com/WV3gZjFwqNqITsMufIEp)
2. Ensure your firewall is open.
  - Default port for incoming shreds is **20000/udp.**
  - NAT connections currently not supported.
  - If you use a firewall, see the firewall [configuration section](https://docs.jito.wtf/lowlatencytxnfeed/#firewall-configuration)
3. Find your TVU port

```bash
export LEDGER_DIR=/mnt/ledger; bash -c "$(curl -fsSL https://raw.githubusercontent.com/jito-labs/shredstream-proxy/master/scripts/get_tvu_port.sh)"
```


Next, open the [`shredstream.sh`](./bin/shredstream.sh) file for editing:

```bash
vi /home/sol/bin/shredstream.sh
```
Then

```bash
chmod +x /home/sol/bin/shredstream.sh
```

#### Create a System Service

You can use the [`shredstream.service`](./system/shredstream.service) from this repo or `sudo vi /etc/systemd/system/shredstream.service` and paste

```ini
[Unit]
Description=Shredstream Proxy
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
LogRateLimitIntervalSec=0
User=sol
Environment="PATH=/home/sol/shredstream-proxy/bin"
Environment="RUST_LOG=info"
ExecStart=/home/sol/bin/shredstream.sh

[Install]
WantedBy=multi-user.target
```

> [!NOTE]
> do not forget to add rules for your firewall from the list 
> https://docs.jito.wtf/lowlatencytxnfeed/#firewall-configuration

#### Enable and start System Service

```bash
sudo systemctl enable --now shredstream
```

```bash
sudo systemctl status shredstream.service
```

## 📝 Cheat Sheet

| Command                          | Description                         |
| -------------------------------- | ----------------------------------- |
| `tail -f ~/agave-validator.log`  | follow the logs of the Agave node   |
| `agave-validator monitor`        | monitor the validator               |
| `solana validators`              | check list of validators            |
| `solana catchup --our-localhost` | check how far it is from chain head |
| `btop`                           | monitor server resources            |
| `iostat -mdx`                    | check NVMe utilization              |

## 🎉 Credits

- [Anza](https://docs.anza.xyz/operations/setup-an-rpc-node)
- [1000x.sh](https://1000x.sh)
- [StakeWare](https://www.stakeware.xyz)
- [Jito](https://docs.jito.wtf/lowlatencytxnfeed/)

## 🔗 Links

- [XFS Performance](https://wiki.archlinux.org/title/XFS#Performance)
