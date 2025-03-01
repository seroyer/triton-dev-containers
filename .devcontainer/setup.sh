#! /bin/bash -e
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2024-2025 Red Hat, Inc.

set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")

declare -a files=(
    "$SCRIPT_DIR/triton/devcontainer.json"
    "$SCRIPT_DIR/triton-amd/devcontainer.json"
    "$SCRIPT_DIR/triton-cpu/devcontainer.json"
)

# Get the current user's UID and GID
UID_VAL=$(id -u)
GID_VAL=$(id -g)

# Function to detect NVIDIA CDI
is_nvidia_cdi_available() {
    if command -v nvidia-ctk &> /dev/null && nvidia-ctk cdi list | grep -q "nvidia.com/gpu=all"; then
        return 0
    fi
    return 1
}

# Update devcontainer.json with the correct UID and GID
for var in "${files[@]}"; do
    if [ -f "$var" ]; then
        sed -i "s/\"--userns=keep-id:uid=[0-9]\+,gid=[0-9]\+\"/\"--userns=keep-id:uid=$UID_VAL,gid=$GID_VAL\"/" "$var"

        # Update devcontainer.json with the correct gpu flags if CDI is available
        if is_nvidia_cdi_available; then
            sed -i "/--runtime=nvidia/d" "$var"
            sed -i "s/\"--gpus all\"/\"--device nvidia.com/gpu=all\"/" "$var"
        fi
    fi
done
