#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo >&2 "Usage: $0 CONFIG"
    exit 1
fi

HERE=$(realpath "$(dirname $0)")
CONFIG="$(realpath $1)"

if [[ ! -f $CONFIG/montagu.yml ]]; then
    echo >&2 "$1 is not a valid montagu configuration path"
    exit 1
fi

if ! MONTAGU="$(which montagu)"; then
    echo >&2 "Could not locate the montagu deployment tool"
    exit 1
fi

# these need to be exported for envsubst
export CONFIG MONTAGU

echo >&2 "Installing systemd units..."
envsubst < $HERE/systemd/montagu-renew-certificate.service | \
    sudo install -T -m644 /dev/stdin /etc/systemd/system/montagu-renew-certificate.service
sudo install -T -m644 $HERE/systemd/montagu-renew-certificate.timer /etc/systemd/system/montagu-renew-certificate.timer

echo >&2 "Enabling timer..."
sudo systemctl daemon-reload
sudo systemctl enable --now montagu-renew-certificate.timer

sudo systemctl status --no-pager montagu-renew-certificate.timer
