#!/bin/bash
# batch start consul-template
[[ "$DEBUG" ]] && set -x

# global function
ts() {
  TS=$(date +%F-%T | tr ':-' '_')
  echo "$TS $*"
}

log() {
  ts "[info] $*" 
}

warn() {
  ts "[warn] $*" >&2
  exit 1
}

DIR=$(dirname $(pwd)/$0)
DIR="${DIR:-"/web/deadlock"}"
N=0
PT_TOOL="$DIR/bin/pt-deadlock-logger"
if [ ! -x $PT_TOOL ]; then
  warn "can not find pt-deadlock-logger command or has no permission."
fi

pt_exec() {
  Host=$1
  Port=$2

  if $(run_check $Host $Port); then
    log "already run deadlock for MySQL $Host:$Port"
  else 
    log "check $Host:$Port ..."
      $PT_TOOL --config $DIR/etc/pt.conf \
          h=$Host,P=$Port,A=utf8 \
          --log $DIR/log/deadlock_$Host-$Port\.log --daemonize 2>/dev/null
  fi
}

run_check() {
  [ ! "$(ps aux | grep h=$1,P=$2 | awk '{print $11}')" = "grep" ]
}

store_pid() {
  pids="$pids $1"
}


pids=""
while read Host Port; do
  N=$((N+1))
  pt_exec $Host $Port &

  pid="$(jobs -p %%)"
  store_pid "$pid"

  # reset N value
  [[ "$N" -eq 5 ]] && {
    wait $pids && N=0
    pids=""
  }
done < <(grep -v -P '^#' $DIR/etc/host.list)

# wait all process done
wait $pids
