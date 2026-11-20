#!/usr/bin/env bash
set -euo pipefail

export PATH="$PATH:/usr/sbin:/sbin"

section() {
  printf '\n== %s ==\n' "$1"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

run() {
  if ! have "$1"; then
    echo "not available ($1 is not installed)"
    return 0
  fi
  "$@" 2>&1 || echo "not available ($1 exited with $?, some checks need root)"
}

list_or_none() {
  if [[ -n $1 ]]; then
    printf '%s\n' "$1"
  else
    echo "none"
  fi
}

docker_ready() {
  if ! have docker; then
    echo "not available (docker is not installed)"
    return 1
  fi
  local out
  if ! out=$(docker ps -q 2>&1); then
    echo "not available ($out)"
    return 1
  fi
}

os_and_kernel() {
  section "os and kernel"
  if [[ -r /etc/os-release ]]; then
    sed -n 's/^PRETTY_NAME=//p' /etc/os-release | tr -d '"'
  else
    echo "not available (/etc/os-release is not readable)"
  fi
  run uname -srm
  if [[ -e /var/run/reboot-required ]]; then
    echo "reboot required: yes"
  else
    echo "reboot required: no"
  fi
}

memory_and_swap() {
  section "memory and swap"
  run free -h
  run swapon --show
}

disk() {
  section "disk"
  run df -h -x tmpfs -x devtmpfs -x overlay
}

firewall() {
  section "ufw status"
  run ufw status verbose
}

ssh_settings() {
  section "effective ssh settings"
  if ! have sshd; then
    echo "not available (sshd is not installed)"
    return 0
  fi
  local out
  if ! out=$(sshd -T 2>&1); then
    echo "not available ($out)"
    return 0
  fi
  grep -E '^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin|pubkeyauthentication) ' <<<"$out"
}

listening_ports() {
  section "listening ports"
  run ss -tulpn
}

docker_daemon_config() {
  section "/etc/docker/daemon.json"
  if [[ ! -e /etc/docker/daemon.json ]]; then
    echo "absent"
    return 0
  fi
  run cat /etc/docker/daemon.json
}

containers_without_memory_limit() {
  section "containers with no memory limit"
  docker_ready || return 0
  local ids out
  ids=$(docker ps -q)
  out=""
  if [[ -n $ids ]]; then
    # shellcheck disable=SC2086
    if ! out=$(docker inspect --format '{{.Name}} {{.HostConfig.Memory}}' $ids 2>&1); then
      echo "not available ($out)"
      return 0
    fi
    out=$(awk '$2 == 0 { sub("^/", "", $1); print $1 }' <<<"$out")
  fi
  list_or_none "$out"
}

containers_on_latest() {
  section "containers on the latest tag"
  docker_ready || return 0
  local out
  # an image reference with neither a tag nor a digest also means latest
  out=$(docker ps --format '{{.Names}} {{.Image}}' | awk '{
    n = split($2, parts, "/")
    if ($2 !~ /@/ && (parts[n] ~ /:latest$/ || parts[n] !~ /:/)) print
  }')
  list_or_none "$out"
}

unhealthy_containers() {
  section "unhealthy containers"
  docker_ready || return 0
  local out
  out=$(docker ps --filter health=unhealthy --format '{{.Names}} {{.Status}}')
  list_or_none "$out"
}

brute_force_protection() {
  section "fail2ban sshd jail"
  run fail2ban-client status sshd
}

automatic_upgrades() {
  section "unattended-upgrades"
  echo "service enabled:"
  run systemctl is-enabled unattended-upgrades
  echo "periodic setting (1 means daily, empty means off):"
  run apt-config dump APT::Periodic::Unattended-Upgrade
}

docker_group() {
  section "docker group members"
  if ! have getent; then
    echo "not available (getent is not installed)"
    return 0
  fi
  local entry
  if ! entry=$(getent group docker); then
    echo "not available (there is no docker group)"
    return 0
  fi
  list_or_none "$(cut -d: -f4 <<<"$entry" | tr ',' '\n')"
}

os_and_kernel
memory_and_swap
disk
firewall
ssh_settings
listening_ports
docker_daemon_config
containers_without_memory_limit
containers_on_latest
unhealthy_containers
brute_force_protection
automatic_upgrades
docker_group
