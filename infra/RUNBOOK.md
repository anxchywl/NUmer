# Host Hardening Runbook

For an Ubuntu 24.04 host that runs several Docker Compose projects behind one reverse proxy.
`host/audit.sh` reads, `host/harden.sh` changes one thing at a time and only when told to.

## Before you start

- Open a second SSH session and keep it open until the end. It is your way back if a change
  cuts off new logins.
- Have the provider's console at hand and check that you can log in there. A console login
  may need an account password, which SSH changes do not affect.
- Copy `infra/host/` to the server and run the commands below from the repository root or
  adjust the paths.
- Make sure the account you run `sudo` from has your public key in `~/.ssh/authorized_keys`,
  and that you have logged in with that key at least once.

## Audit

```bash
sudo bash infra/host/audit.sh
```

It changes nothing. Without `sudo` several sections report `not available`.

| Section | What it shows | What is normal |
|---|---|---|
| os and kernel | release, kernel, pending reboot | a supported release, `reboot required: no` |
| memory and swap | RAM and swap use | available memory well above zero, swap present and mostly unused |
| disk | filesystem use | every filesystem comfortably below 80 percent |
| ufw status | firewall state and rules | `Status: active` with SSH, 80 and 443 allowed |
| effective ssh settings | what `sshd` actually applies, `Match` blocks excluded | passwords and keyboard-interactive `no`, public key `yes`, root `without-password` or `no` |
| listening ports | open TCP and UDP ports and their processes | public listeners are only SSH and the reverse proxy, anything else is bound to loopback |
| /etc/docker/daemon.json | daemon settings | a log driver with `max-size` and `max-file` |
| containers with no memory limit | containers that can take all the memory | `none` |
| containers on the latest tag | containers whose version is not pinned | `none` |
| unhealthy containers | failing health checks | `none` |
| fail2ban sshd jail | brute-force protection | a jail status with counters |
| unattended-upgrades | automatic security updates | `enabled` and a periodic setting of `1` |
| docker group members | accounts that are effectively root | only accounts you expect |

## Apply

First read the plan. It changes nothing.

```bash
sudo bash infra/host/harden.sh
```

Then apply one step at a time in this order. Each step prints the commands that undo it, so
save that output. Running a step again changes nothing. A step that needs a missing tool says
so and stops, install the tool yourself and run it again.

### 1. sysctl

Sets `vm.swappiness=10`.

```bash
sudo bash infra/host/harden.sh --apply sysctl
```

Check that `sysctl -n vm.swappiness` prints `10`. If the step lists another file that sets the
same value, that file may win after a reboot.

### 2. fail2ban

Enables the `sshd` jail and restarts `fail2ban`. If `/etc/fail2ban/jail.d/sshd.local` already
has other settings, the step does not overwrite it.

```bash
sudo bash infra/host/harden.sh --apply fail2ban
```

Check that `sudo fail2ban-client status sshd` shows the jail. Repeated failed logins from your
own address can ban it for a while, so use the console or another network if that happens.

### 3. ufw

Allows SSH, 80/tcp, 443/tcp and 443/udp, then enables the firewall. It refuses when SSH listens
on any port other than 22.

Before applying, look at the listening ports in the audit: a public port of a service that does
not run in Docker is blocked once the firewall is on.

```bash
sudo bash infra/host/harden.sh --apply ufw
```

Check that a new SSH session connects, `sudo ufw status` lists the rules and your public sites
still answer.

### 4. ssh

Writes `/etc/ssh/sshd_config.d/00-numer.conf` to turn off password and keyboard-interactive
login and to allow root only with a key. A root login setting that is already stricter is kept.
The file sorts first because `sshd` keeps the first value it reads. The step validates the
result and removes the file if validation fails, another setting overrides it or the reload
fails.

```bash
sudo bash infra/host/harden.sh --apply ssh
```

Check, from your own machine, that a new session connects with your key. Close the second
session only after that works.

### 5. docker-logs

Limits each container log to three files of 10 MB. Other keys in `daemon.json` are kept and
the old file is backed up. If another log driver was configured, it is replaced together with
its options.

```bash
sudo bash infra/host/harden.sh --apply docker-logs
```

This only writes the file. It takes effect after a Docker daemon restart, which restarts every
container of every project. Do that in a quiet hour. Containers without a restart policy stay
stopped, so note what is running first:

```bash
sudo docker ps --format '{{.Names}} {{.Status}}'
```

```bash
sudo bash infra/host/harden.sh --apply docker-logs --restart-docker
```

The script waits 10 seconds before restarting. Check that the same containers are running and
healthy afterwards. A container created before the restart keeps its old log settings until its
project recreates it, for example with `docker compose up -d --force-recreate` run from that
project at a time that suits it.

## Undo

Run the commands the step printed. If the output is lost:

| Step | Undo |
|---|---|
| sysctl | remove `/etc/sysctl.d/90-numer.conf`, then `sudo sysctl -w vm.swappiness=<old value>`, the kernel default is 60 |
| fail2ban | remove `/etc/fail2ban/jail.d/sshd.local` if the step created it, then `sudo systemctl restart fail2ban` |
| ufw | `sudo ufw disable`, and `sudo ufw delete allow <rule>` for rules the step added |
| ssh | remove `/etc/ssh/sshd_config.d/00-numer.conf`, then `sudo sshd -t` and `sudo systemctl reload ssh` |
| docker-logs | copy the newest `/etc/docker/daemon.json.bak-*` back, or remove `daemon.json` if it did not exist, then restart Docker in a quiet hour |

If SSH no longer accepts you, use the open session or the provider console and run the `ssh`
undo there.

## What this does not do

- It does not change other projects' compose files, memory limits or images.
- It does not rotate keys, add or remove accounts, or change the `docker` group.
- It does not install or upgrade packages, enable unattended upgrades, add swap or reboot.
- It does not disable root login outright or change the SSH port.
- `ufw` does not filter ports that Docker publishes. With only the reverse proxy publishing
  ports, enabling it changes nothing that is reachable today. It guards against a future
  service listening on the host by mistake, not against a new published container port.

## Memory limits

The audit lists containers with no limit. To see use against limits:

```bash
sudo docker stats --no-stream
```

`MEM USAGE / LIMIT` shows current use and the limit. A limit equal to the host's total memory
means no limit is set. One reading is a snapshot, so take several over a normal week and during
the busiest work, such as imports, backups and deploys, and keep the highest value.

Set the limit to about twice the observed peak. A limit far above that protects little, a limit
close to the peak gets the container killed on an ordinary spike. Before applying new limits,
add them up and compare with the host's memory, leaving room for the system itself. Set each
limit in the compose file of the project that owns the container, then recreate that service.
