#!/bin/bash
# poll-ci - Poll GitHub CI checks until all complete
# Used by analyze-ci skill. Resilient to network hiccups.
# Usage: poll-ci [--interval SECONDS] [--timeout SECONDS]
#
# Defaults: interval=30s, timeout=3600s (1h)

set -euo pipefail

INTERVAL=30
TIMEOUT=3600

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval) INTERVAL="$2"; shift 2 ;;
    --timeout)  TIMEOUT="$2"; shift 2 ;;
    *)          echo "Unknown arg: $1"; exit 1 ;;
  esac
done

START=$(date +%s)

while true; do
  ELAPSED=$(( $(date +%s) - START ))
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "[$(date +%H:%M:%S)] Timeout after ${TIMEOUT}s"
    gh pr checks 2>/dev/null || true
    exit 1
  fi

  status=$(gh pr checks --json name,state,bucket 2>&1)
  if [ $? -ne 0 ]; then
    echo "[$(date +%H:%M:%S)] gh error (retrying in ${INTERVAL}s): $status"
    sleep "$INTERVAL"
    continue
  fi

  pending=$(echo "$status" | grep -c '"pending"' || true)
  if [ "$pending" -eq 0 ]; then
    echo "[$(date +%H:%M:%S)] All checks complete!"
    gh pr checks
    exit 0
  fi

  echo "[$(date +%H:%M:%S)] ${pending} checks still pending..."
  sleep "$INTERVAL"
done
