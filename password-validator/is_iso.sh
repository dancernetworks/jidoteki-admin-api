#!/bin/sh

set -u
set -e

if [[ -f /data/iso ]]; then
  echo "true"
fi
echo "false"
