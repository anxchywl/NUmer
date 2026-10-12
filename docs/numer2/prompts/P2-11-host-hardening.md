# P2-11: Host hardening script and runbook

**Recommended model:** sonnet   **Effort:** high
**Risk:** low for the script, high when applied   **Est.:** 5 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** none

## Goal
The server that hosts the module backends is shared with the owner's other projects and was
hardened by hand. Give the owner a read-only audit script, a hardening script that changes
nothing unless told to, step by step, and a runbook. The executor never connects to the
server.

## Read first
- `AGENTS.md`
- `docs/numer2/RESEARCH.md` section 9.4
- `infra/backup/README.md` (tone and structure)

## Context
- Target: an Ubuntu 24.04 host running Docker with Compose v2 and several compose projects
  owned by the same person, with one reverse proxy container publishing ports 80 and 443
  (and 443 over UDP) and SSH on port 22. Assume nothing else about its state: the audit
  script is what finds out.
- What the scripts must be able to detect and fix, because no setup script in the module
  repos covers all of it: an inactive firewall; SSH that still allows password login; no
  Docker log rotation; containers with no memory limit or one far above their use; no SSH
  brute-force protection.
- `ufw` does not filter ports that Docker publishes. Only the reverse proxy publishes ports,
  so enabling `ufw` with SSH, 80 and 443 allowed does not change what is reachable; it
  protects against a future mistake.
- Changing `/etc/docker/daemon.json` takes effect only after the Docker daemon restarts,
  which restarts every container of every project. The script must never do that restart
  unless a separate flag is given.
- Locking yourself out of SSH is the main risk. Every SSH change is validated with
  `sshd -t` before reload, and the script refuses to disable password login when the
  invoking account has no `authorized_keys`.

## Steps
1. `infra/host/audit.sh`: read-only, prints a plain-text report to stdout and writes nothing.
   Sections: OS and kernel, and whether `/var/run/reboot-required` exists; memory and swap;
   disk; `ufw status`; effective SSH settings from `sshd -T` for `passwordauthentication`,
   `kbdinteractiveauthentication`, `permitrootlogin`, `pubkeyauthentication`; listening TCP and
   UDP ports with the process name; the content of `/etc/docker/daemon.json` or `absent`;
   containers with no memory limit; containers whose image tag is `latest`; containers
   reporting `unhealthy`; whether `fail2ban` has an active `sshd` jail; whether
   `unattended-upgrades` is enabled; members of the `docker` group. It must run to the end even
   when a tool is missing, printing `not available` for that section.
2. `infra/host/harden.sh`. With no arguments it prints, for every step, the current state and
   what it would change, and changes nothing. `--apply <step>` applies one step; steps:
   - `ufw`: `ufw allow OpenSSH`, `80/tcp`, `443/tcp`, `443/udp`, then `ufw --force enable`.
     Refuses when the SSH daemon listens on a port other than 22 (the profile would not match).
   - `ssh`: writes `/etc/ssh/sshd_config.d/90-numer.conf` with `PasswordAuthentication no`,
     `KbdInteractiveAuthentication no`, `PermitRootLogin prohibit-password`; runs `sshd -t`;
     reloads only on success; on failure removes the file. Refuses when the invoking user has
     no non-empty `~/.ssh/authorized_keys`.
   - `docker-logs`: backs up `/etc/docker/daemon.json` (if present) with a timestamp suffix and
     merges `{"log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "3"}}`
     into it with `python3`, preserving other keys. It prints that a daemon restart is needed
     and does not restart. `--apply docker-logs --restart-docker` also restarts the daemon,
     after printing a warning and waiting 10 seconds.
   - `sysctl`: writes `/etc/sysctl.d/90-numer.conf` with `vm.swappiness=10` and applies it.
   - `fail2ban`: ensures `/etc/fail2ban/jail.d/sshd.local` enables the `sshd` jail and
     restarts `fail2ban`.
   Every applied step prints the exact commands that undo it. The script requires root for
   `--apply` and refuses an unknown step. It is idempotent: applying a step twice changes
   nothing the second time.
3. `infra/host/test/run.sh`: needs Docker. In an `ubuntu:24.04` container with `ufw`,
   `openssh-server`, `python3` and `fail2ban` installed: run `harden.sh` with no arguments and
   assert that no file under `/etc` changed (compare a checksum listing before and after); run
   `--apply sysctl` twice and assert the file exists and the second run reports no change; run
   `--apply docker-logs` against a prepared `daemon.json` with an extra key and assert the key
   survives, the backup exists and no restart was attempted; run `--apply ssh` as a user
   without `authorized_keys` and assert it refuses; run `--apply nonsense` and assert a
   non-zero exit. Steps that need a real kernel firewall are not tested; say so in the output.
4. `infra/RUNBOOK.md`, sections: `Before you start` (a second SSH session stays open; a
   provider console is at hand); `Audit` (run it, what each section means, what is normal);
   `Apply` (the order `sysctl`, `fail2ban`, `ufw`, `ssh`, `docker-logs`; what to check after
   each; the Docker restart belongs in a quiet hour because it restarts every project);
   `Undo`; `What this does not do` (it does not change other projects' compose files, memory
   limits or images; it does not rotate keys); `Memory limits` (how to read
   `docker stats --no-stream` against limits and how to decide a limit: about twice the
   observed peak). No server address, hostname or project list.
5. Add `infra/host/test/run.sh` and `shellcheck infra/host/*.sh` to the CI `infra` job.

## Non-goals
- The executor does not run either script against any real machine.
- Do not restart Docker, reboot, upgrade packages or stop containers in any step that the owner has not explicitly flagged.
- Do not disable root login outright or change the SSH port.
- Do not edit other projects' files.
- Do not install packages in `harden.sh` except nothing: if a tool is missing, the step says so and stops.

## Constraints
- No file may contain a server address, a real domain that is not already public in a module repo, a credential or a key.
- Scripts are POSIX-friendly bash with `set -euo pipefail`, pass `shellcheck`, and never act on production data by default.
- The executor does not connect to any server. The deliverable is code and documentation that the owner runs.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `shellcheck infra/host/audit.sh infra/host/harden.sh infra/host/test/run.sh` exits 0.
- [ ] `bash infra/host/test/run.sh` exits 0 and prints each of its five assertions as passed.
- [ ] `bash infra/host/harden.sh` as a normal user prints a plan and exits 0 without writing anything.
- [ ] `grep -rnE "([0-9]{1,3}\.){3}[0-9]{1,3}" infra` prints nothing.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Approval needed: run the audit, read it, then apply step by step with a second SSH session open; schedule the Docker restart (`docs/numer2/USER_ACTIONS.md` D-7).

## Deliverable
Branch `numer2/p2-11-host-hardening`, one commit, message `feat: add host audit and hardening scripts with runbook` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- Docker is not available to run the container test.
- A step cannot be made idempotent without parsing a file format the script should not parse (propose dropping the step).
