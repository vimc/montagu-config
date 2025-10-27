#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 0 ]]; then
    echo >&2 "Usage: $0"
    exit 1
fi

HERE=$(realpath "$(dirname $0)")

if ! MONTAGU="$(which montagu)"; then
    echo >&2 "Could not locate the montagu deployment tool"
    exit 1
fi

if [[ ! -f .montagu_identity ]]; then
    echo >&2 "montagu is not configured, run montagu configure first"
    exit 1
fi

# this need to be exported for envsubst
export MONTAGU

echo >&2 "Installing systemd units..."
envsubst < $HERE/systemd/montagu-renew-certificate.service | \
    sudo install -T -m644 /dev/stdin /etc/systemd/system/montagu-renew-certificate.service
sudo install -T -m644 $HERE/systemd/montagu-renew-certificate.timer /etc/systemd/system/montagu-renew-certificate.timer

echo >&2 "Enabling timer..."
sudo systemctl daemon-reload
sudo systemctl enable --now montagu-renew-certificate.timer

sudo systemctl status --no-pager montagu-renew-certificate.timer
