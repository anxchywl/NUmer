#!/usr/bin/env bash
set -euo pipefail

export PATH="$PATH:/usr/sbin:/sbin"

readonly STEPS=(sysctl fail2ban ufw ssh docker-logs)
readonly UFW_RULES=(OpenSSH 80/tcp 443/tcp 443/udp)
readonly SYSCTL_FILE=/etc/sysctl.d/90-numer.conf
# sshd keeps the first value it reads, so this must sort before 50-cloud-init.conf
readonly SSH_FILE=/etc/ssh/sshd_config.d/00-numer.conf
readonly JAIL_FILE=/etc/fail2ban/jail.d/sshd.local
readonly DAEMON_FILE=/etc/docker/daemon.json

mode=plan
restart_docker=no
backup=""

usage() {
  echo "usage: harden.sh [--apply <step> [--restart-docker]]"
  echo "steps: ${STEPS[*]}"
  echo "--restart-docker is accepted only with --apply docker-logs"
}

say() {
  printf '%s\n' "$@" | sed 's/^/  /'
}

refuse() {
  printf 'refused: %s\n' "$1" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

need() {
  local tool
  for tool in "$@"; do
    if ! have "$tool"; then
      say "missing tool: $tool, nothing done for this step"
      if [[ $mode == apply ]]; then
        exit 1
      fi
      return 1
    fi
  done
}

has_content() {
  [[ -f $1 ]] && [[ $(cat "$1") == "$2" ]]
}

backup_file() {
  backup=""
  if [[ -e $1 ]]; then
    backup="$1.bak-$(date +%Y%m%d%H%M%S)"
    cp -p "$1" "$backup"
    say "backup: $backup"
  fi
}

write_file() {
  mkdir -p "$(dirname "$1")"
  backup_file "$1"
  printf '%s\n' "$2" >"$1"
  chmod 644 "$1"
  say "wrote $1"
}

restore_file() {
  if [[ -n $backup ]]; then
    cp -p "$backup" "$1"
    say "restored $1 from $backup"
  else
    rm -f "$1"
    say "removed $1"
  fi
}

undo_file_command() {
  if [[ -n $backup ]]; then
    say "  cp -p $backup $1"
  else
    say "  rm $1"
  fi
}

step_sysctl() {
  echo "step sysctl"
  need sysctl || return 0
  local content="vm.swappiness=10" current others
  current=$(sysctl -n vm.swappiness)
  say "current: vm.swappiness=$current"
  others=$(grep -lE '^[[:space:]]*vm\.swappiness' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | grep -vxF "$SYSCTL_FILE" || true)
  if [[ -n $others ]]; then
    say "also set in (a later file wins at boot):" "$others"
  fi
  if has_content "$SYSCTL_FILE" "$content" && [[ $current == 10 ]]; then
    say "no change"
    return 0
  fi
  if [[ $mode == plan ]]; then
    say "would write $SYSCTL_FILE with $content and apply it"
    return 0
  fi
  write_file "$SYSCTL_FILE" "$content"
  say "undo:"
  undo_file_command "$SYSCTL_FILE"
  say "  sysctl -w vm.swappiness=$current"
  sysctl -p "$SYSCTL_FILE"
}

jail_active() {
  fail2ban-client status sshd >/dev/null 2>&1
}

step_fail2ban() {
  echo "step fail2ban"
  need fail2ban-client systemctl || return 0
  local content=$'[sshd]\nenabled = true' active=no
  if jail_active; then
    active=yes
    say "current: sshd jail active"
  else
    say "current: sshd jail not active, or not readable without root"
  fi
  if [[ -e $JAIL_FILE ]] && ! has_content "$JAIL_FILE" "$content"; then
    if [[ $active == yes ]]; then
      say "no change: $JAIL_FILE has its own settings and the jail is active"
      return 0
    fi
    say "$JAIL_FILE exists with other settings, enable the sshd jail there by hand"
    if [[ $mode == apply ]]; then
      refuse "will not overwrite $JAIL_FILE"
    fi
    return 0
  fi
  if has_content "$JAIL_FILE" "$content" && [[ $active == yes ]]; then
    say "no change"
    return 0
  fi
  if [[ $mode == plan ]]; then
    say "would ensure $JAIL_FILE enables the sshd jail and restart fail2ban"
    return 0
  fi
  if has_content "$JAIL_FILE" "$content"; then
    say "$JAIL_FILE is already in place, restarting fail2ban"
  else
    write_file "$JAIL_FILE" "$content"
    say "undo:"
    undo_file_command "$JAIL_FILE"
    say "  systemctl restart fail2ban"
  fi
  systemctl restart fail2ban
  say "check: fail2ban-client status sshd"
}

ssh_ports() {
  local config
  config=$(sshd -T 2>/dev/null) || return 1
  awk '$1 == "port" { print $2 }' <<<"$config"
  # with socket activation the listening port comes from the socket unit, not sshd_config
  if have systemctl && systemctl is-active --quiet ssh.socket; then
    systemctl show ssh.socket -p Listen | sed -nE 's/^(.*[^0-9])?([0-9]+) \(Stream\)$/\2/p'
  fi
}

step_ufw() {
  echo "step ufw"
  need ufw sshd || return 0
  local status added ports rule active=no
  local missing=()

  if ports=$(ssh_ports); then
    ports=$(sort -u <<<"$ports" | tr '\n' ' ')
    ports=${ports% }
    say "current: ssh listens on port $ports"
  else
    ports=""
    say "current: ssh port not readable without root"
  fi

  if status=$(ufw status 2>&1) && added=$(ufw show added 2>&1); then
    if grep -qx 'Status: active' <<<"$status"; then
      active=yes
    fi
    say "current: ufw active: $active"
    for rule in "${UFW_RULES[@]}"; do
      grep -qxF "ufw allow $rule" <<<"$added" || missing+=("$rule")
    done
  else
    say "current: ufw state not readable: $status"
    if [[ $mode == apply ]]; then
      refuse "cannot read the ufw state"
    fi
    missing=("${UFW_RULES[@]}")
  fi

  if [[ -n $ports && $ports != 22 ]]; then
    say "ssh does not listen on port 22 only, the OpenSSH profile would not match"
    if [[ $mode == apply ]]; then
      refuse "ssh listens on port $ports"
    fi
    return 0
  fi

  if [[ $active == yes && ${#missing[@]} -eq 0 ]]; then
    say "no change"
    return 0
  fi

  if [[ $mode == plan ]]; then
    for rule in ${missing[@]+"${missing[@]}"}; do
      say "would run: ufw allow $rule"
    done
    if [[ $active == no ]]; then
      say "would run: ufw --force enable"
      say "enabling blocks every other incoming port of non-docker services"
    fi
    return 0
  fi

  if [[ -z $ports ]]; then
    refuse "cannot determine the ssh port"
  fi
  say "undo:"
  if [[ $active == no ]]; then
    say "  ufw disable"
  fi
  for rule in ${missing[@]+"${missing[@]}"}; do
    say "  ufw delete allow $rule"
  done
  for rule in ${missing[@]+"${missing[@]}"}; do
    ufw allow "$rule"
  done
  if [[ $active == no ]]; then
    ufw --force enable
  fi
}

ssh_value() {
  awk -v key="$1" '$1 == key { print $2 }' <<<"$2"
}

step_ssh() {
  echo "step ssh"
  need sshd getent || return 0
  local user home keys config="" usable_key=no
  local content=$'PasswordAuthentication no\nKbdInteractiveAuthentication no'
  local root_login=""

  user=${SUDO_USER:-$(id -un)}
  home=$(getent passwd "$user" | cut -d: -f6)
  keys="$home/.ssh/authorized_keys"
  if [[ -r $keys ]] && grep -qE '^[[:space:]]*[^#[:space:]]' "$keys"; then
    usable_key=yes
  fi
  say "current: $user has a key in $keys: $usable_key"

  if config=$(sshd -T 2>&1); then
    root_login=$(ssh_value permitrootlogin "$config")
    say "current: passwordauthentication $(ssh_value passwordauthentication "$config")"
    say "current: kbdinteractiveauthentication $(ssh_value kbdinteractiveauthentication "$config")"
    say "current: permitrootlogin $root_login"
    say "current: pubkeyauthentication $(ssh_value pubkeyauthentication "$config")"
  else
    say "current: effective settings not readable: $config"
    config=""
  fi

  # a stricter root login setting is left as it is
  if [[ $root_login != no && $root_login != forced-commands-only ]]; then
    content+=$'\nPermitRootLogin prohibit-password'
  fi

  if [[ $mode == apply ]]; then
    if [[ $usable_key == no ]]; then
      refuse "$user has no non-empty authorized_keys at $keys, disabling passwords could lock you out"
    fi
    if [[ -z $config ]]; then
      refuse "sshd -T failed, fix the ssh configuration first"
    fi
    if [[ $(ssh_value pubkeyauthentication "$config") != yes ]]; then
      refuse "public key login is disabled, disabling passwords would lock you out"
    fi
  fi

  if has_content "$SSH_FILE" "$content" && ssh_hardened "$config"; then
    say "no change"
    return 0
  fi
  if [[ $mode == plan ]]; then
    say "would write $SSH_FILE:" "$content"
    say "would validate with sshd -t and reload ssh"
    return 0
  fi
  need systemctl

  write_file "$SSH_FILE" "$content"
  if ! sshd -t; then
    restore_file "$SSH_FILE"
    refuse "sshd -t rejected the configuration"
  fi
  config=$(sshd -T)
  if ! ssh_hardened "$config"; then
    restore_file "$SSH_FILE"
    grep -rniE '^[[:space:]]*(passwordauthentication|kbdinteractiveauthentication|permitrootlogin|include)' \
      /etc/ssh/sshd_config /etc/ssh/sshd_config.d >&2 || true
    refuse "another ssh setting overrides $SSH_FILE, see the lines above"
  fi
  # an inactive socket-activated service reads the new file when it next starts
  if systemctl is-active --quiet ssh; then
    if ! systemctl reload ssh; then
      restore_file "$SSH_FILE"
      refuse "ssh did not reload"
    fi
    say "reloaded ssh"
  else
    say "ssh service is not running, the file applies when it next starts"
  fi
  say "undo:"
  undo_file_command "$SSH_FILE"
  say "  sshd -t && systemctl reload ssh"
  say "now open a new ssh session before closing this one"
}

ssh_hardened() {
  local root_login
  root_login=$(ssh_value permitrootlogin "$1")
  [[ $(ssh_value passwordauthentication "$1") == no ]] &&
    [[ $(ssh_value kbdinteractiveauthentication "$1") == no ]] &&
    [[ $root_login =~ ^(no|forced-commands-only|prohibit-password|without-password)$ ]]
}

merged_daemon_config() {
  python3 -I -c '
import json, os, sys

path = sys.argv[1]
config = {}
if os.path.exists(path):
    with open(path) as handle:
        config = json.load(handle)
wanted = {"max-size": "10m", "max-file": "3"}
options = config.get("log-opts", {}) if config.get("log-driver", "json-file") == "json-file" else {}
merged = dict(config)
merged["log-driver"] = "json-file"
merged["log-opts"] = {**options, **wanted}
if merged == config:
    sys.exit(0)
print(json.dumps(merged, indent=2))
' "$DAEMON_FILE"
}

step_docker_logs() {
  echo "step docker-logs"
  need python3 || return 0
  if [[ $restart_docker == yes ]]; then
    need docker systemctl
  fi
  local merged temp
  if [[ -e $DAEMON_FILE ]]; then
    say "current $DAEMON_FILE:" "$(cat "$DAEMON_FILE")"
  else
    say "current: $DAEMON_FILE absent"
  fi
  if ! merged=$(merged_daemon_config); then
    say "$DAEMON_FILE could not be merged, it is left as it is"
    if [[ $mode == apply ]]; then
      exit 1
    fi
    return 0
  fi

  if [[ -z $merged ]]; then
    say "no change to $DAEMON_FILE"
  elif [[ $mode == plan ]]; then
    say "would write $DAEMON_FILE:" "$merged"
    say "a daemon restart is needed, only --restart-docker performs it"
    return 0
  else
    mkdir -p "$(dirname "$DAEMON_FILE")"
    backup_file "$DAEMON_FILE"
    temp=$(mktemp "$DAEMON_FILE.XXXXXX")
    printf '%s\n' "$merged" >"$temp"
    chmod 644 "$temp"
    mv "$temp" "$DAEMON_FILE"
    say "wrote $DAEMON_FILE"
    say "undo:"
    undo_file_command "$DAEMON_FILE"
    say "  systemctl restart docker   (only if docker was restarted since this change)"
  fi

  if [[ $mode == plan ]]; then
    return 0
  fi
  if [[ $restart_docker == no ]]; then
    say "a daemon restart is needed before this takes effect, docker was not restarted"
    say "containers created before the restart keep their old log settings until recreated"
    return 0
  fi
  say "WARNING: restarting docker in 10 seconds, every container of every project will stop"
  say "containers without a restart policy stay stopped, press ctrl-c to abort"
  sleep 10
  systemctl restart docker
  say "docker restarted, recreate containers for the new log settings to apply to them"
}

run_step() {
  case $1 in
    sysctl) step_sysctl ;;
    fail2ban) step_fail2ban ;;
    ufw) step_ufw ;;
    ssh) step_ssh ;;
    docker-logs) step_docker_logs ;;
  esac
}

main() {
  if [[ $# -eq 0 ]]; then
    echo "plan only, nothing is changed"
    local step
    for step in "${STEPS[@]}"; do
      echo
      run_step "$step"
    done
    return 0
  fi

  if [[ $1 != --apply || $# -lt 2 || $# -gt 3 ]]; then
    usage >&2
    exit 2
  fi
  local selected=$2
  if [[ " ${STEPS[*]} " != *" $selected "* || $selected == *" "* ]]; then
    echo "unknown step: $selected" >&2
    usage >&2
    exit 2
  fi
  if [[ $# -eq 3 ]]; then
    if [[ $3 != --restart-docker || $selected != docker-logs ]]; then
      usage >&2
      exit 2
    fi
    restart_docker=yes
  fi
  if [[ $(id -u) -ne 0 ]]; then
    refuse "--apply needs root"
  fi
  mode=apply
  run_step "$selected"
}

main "$@"
