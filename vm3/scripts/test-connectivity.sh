#!/usr/bin/env bash
set -euo pipefail
cd "/opt/technova-automation"
sudo -u "deploy" ansible all -m ping
