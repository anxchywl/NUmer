#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAILED: %s\n' "$1" >&2
  exit 1
}

passed() {
  printf 'passed: %s\n' "$1"
}

etc_listing() {
  find /etc -type f -exec sha256sum {} + | sort -k2
  find /etc -type l -printf '%p -> %l\n' | sort
  find /etc -printf '%p %m %U %G\n' | sort
}

stub() {
  printf '#!/bin/sh\n%s\n' "$2" >"/usr/local/bin/$1"
  chmod 755 "/usr/local/bin/$1"
}

inside_container() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq >/dev/null
  apt-get install -qq -y --no-install-recommends ufw openssh-server python3 fail2ban >/dev/null
  mkdir -p /run/sshd /etc/docker
  useradd --create-home nokeys
  mkdir -p /root/.ssh
  echo "ssh-ed25519 placeholder-for-the-test" >/root/.ssh/authorized_keys
  # the kernel settings and service manager of the docker host must stay untouched
  # shellcheck disable=SC2016
  stub sysctl 'case $1 in
-n) cat /tmp/swappiness 2>/dev/null || echo 60 ;;
-p) echo 10 >/tmp/swappiness ;;
*) exit 1 ;;
esac'
  stub systemctl 'echo "$*" >>/tmp/systemctl.log'

  local harden=/src/harden.sh before after output

  before=$(etc_listing)
  bash "$harden" >/tmp/plan-root.txt
  su nokeys -s /bin/bash -c "bash $harden" >/tmp/plan-user.txt
  after=$(etc_listing)
  [[ $before == "$after" ]] || fail "a plan run changed /etc"
  grep -q '^step docker-logs' /tmp/plan-user.txt || fail "the plan stopped early"
  cat /tmp/plan-user.txt
  passed "1/5 a run with no arguments changes nothing under /etc, as root and as a normal user"

  bash "$harden" --apply sysctl >/dev/null
  [[ $(cat /etc/sysctl.d/90-numer.conf) == "vm.swappiness=10" ]] || fail "sysctl file is missing or wrong"
  before=$(etc_listing)
  output=$(bash "$harden" --apply sysctl)
  after=$(etc_listing)
  grep -q 'no change' <<<"$output" || fail "the second sysctl run did not report no change"
  [[ $before == "$after" ]] || fail "the second sysctl run changed /etc"
  passed "2/5 sysctl writes its file once and the second run reports no change"

  echo '{"live-restore": true}' >/etc/docker/daemon.json
  : >/tmp/systemctl.log
  bash "$harden" --apply docker-logs >/dev/null
  python3 -I -c '
import json
config = json.load(open("/etc/docker/daemon.json"))
assert config == {
    "live-restore": True,
    "log-driver": "json-file",
    "log-opts": {"max-size": "10m", "max-file": "3"},
}, config
' || fail "daemon.json was not merged as expected"
  local backups=(/etc/docker/daemon.json.bak-*)
  [[ -f ${backups[0]} && $(cat "${backups[0]}") == '{"live-restore": true}' ]] || fail "no backup of daemon.json"
  [[ ! -s /tmp/systemctl.log ]] || fail "a restart was attempted"
  before=$(etc_listing)
  bash "$harden" --apply docker-logs >/dev/null
  after=$(etc_listing)
  [[ $before == "$after" ]] || fail "the second docker-logs run changed /etc"
  passed "3/5 docker-logs keeps other keys, makes a backup, restarts nothing and is idempotent"

  before=$(etc_listing)
  if output=$(SUDO_USER=nokeys bash "$harden" --apply ssh 2>&1); then
    fail "ssh was applied for a user without authorized_keys"
  fi
  after=$(etc_listing)
  grep -q 'refused: nokeys has no non-empty authorized_keys' <<<"$output" || fail "ssh failed for another reason: $output"
  [[ $before == "$after" ]] || fail "the refused ssh run changed /etc"
  passed "4/5 ssh refuses a user without authorized_keys"

  if bash "$harden" --apply nonsense >/dev/null 2>&1; then
    fail "an unknown step exited zero"
  fi
  passed "5/5 an unknown step exits non-zero"

  echo "not tested: ufw (needs a real kernel firewall), a live fail2ban restart, an ssh reload and a docker daemon restart"
}

if [[ ${1:-} == --inside ]]; then
  inside_container
else
  source_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  docker run --rm -v "$source_dir:/src:ro" ubuntu:24.04 bash /src/test/run.sh --inside
fi
