#! /bin/bash -e
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2024-2025 Red Hat, Inc.

set -euo pipefail

username=""
userid=""
usergid=""

usage() {
  cat <<EOF >&2
Usage: $0
   -u | --user <username>
   -g | --gid <usergid>
   -i | --id <userid>
EOF
  exit 1
}

# Parse command-line arguments
args=$(getopt -o u:g:i: --long user:,gid:,id: -n "$0" -- "$@") || usage

eval set -- "$args"
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      ;;
    -u | --user)
      username="$2"
      shift 2
      ;;
    -g | --gid)
      usergid="$2"
      shift 2
      ;;
    -i | --id)
      userid="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unsupported option: $1" >&2
      usage
      ;;
  esac
done

# Validate required parameters
if [ -z "$username" ] || [ -z "$usergid" ] || [ -z "$userid" ]; then
  echo "Error: --user, --id, and --gid are required." >&2
  usage
fi

USER_NAME="$username"
USER_UID="$userid"
USER_GID="$usergid"
HOME_DIR="/home/$USER_NAME"
DEFAULT_UID=1000

# Exit if the user is root
if [ "$USER_NAME" = "root" ]; then
  exit 0
fi

# Create group if it doesn't exist
if ! getent group "$USER_GID" >/dev/null; then
  groupadd --gid "$USER_GID" "$USER_NAME"
else # modify the name
  gname=$(getent group "$USER_GID" | cut -d: -f1)
  groupmod -g "$USER_GID"  -n "$USER_NAME" "$gname"
fi

# Check if the UID is in use
if getent passwd "$USER_UID" >/dev/null; then
  echo "Warning: UID $USER_UID is already in use. Creating the user with UID $DEFAULT_UID instead." >&2
  USER_UID=$DEFAULT_UID
fi

# Create user if it doesn't exist
if ! getent passwd "$USER_NAME" >/dev/null; then
  useradd --uid "$USER_UID" --gid "$USER_GID" -m "$USER_NAME"
fi

# Ensure $HOME exists when starting
if [ ! -d "${HOME_DIR}" ]; then
  mkdir -p "${HOME_DIR}"
fi

# Add current (arbitrary) user to /etc/passwd and /etc/group
if ! whoami >/dev/null 2>&1; then
  if [ -w /etc/passwd ]; then
    echo "update passwd file"
    echo "${USER_NAME:-user}:x:$(id -u):0:${USER_NAME:-user} user:${HOME}:/bin/bash" >> /etc/passwd
    echo "${USER_NAME:-user}:x:$(id -u):" >> /etc/group
  fi
fi

# Fix up permissions
chown "$USER_NAME:$USER_GID" -R "/home/$USER_NAME"
chown "$USER_NAME:$USER_GID" -R /opt
chown "$USER_NAME:$USER_GID" -R /workspace
mkdir -p "/run/user/$USER_UID"
chown "$USER_NAME:$USER_GID" "/run/user/$USER_UID"
