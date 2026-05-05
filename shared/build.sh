#!/usr/bin/env bash

set -xeuo pipefail

# Use upstream bootc — ZFS support (composefs-backend path) merged as of v1.1.x
git clone --depth 1 --branch v1.15.2 "https://github.com/bootc-dev/bootc.git" .

make bin install-all DESTDIR=/output
