#!/usr/bin/env bash
# Copyright 2026 Ib Helmer Niesen
# SPDX-License-Identifier: Apache-2.0
# Licensed under the Apache License, Version 2.0.
# https://www.apache.org/licenses/LICENSE-2.0
# Distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND.
#
# Create local Linux users from a simple comma-separated file.
# New accounts are password-locked until an administrator sets a password.

set -euo pipefail
export LC_ALL=C

usage() {
    echo "Usage: $0 [--apply] users.csv"
    echo "Default: dry-run. Use --apply as root to create accounts."
}

apply=0
if [[ ${1:-} == --help || ${1:-} == -h ]]; then usage; exit 0; fi
if [[ ${1:-} == --apply ]]; then apply=1; shift; fi
if [[ $# != 1 || ! -f "$1" || ! -r "$1" ]]; then usage >&2; exit 2; fi
if (( apply && EUID != 0 )); then echo "Use sudo with --apply." >&2; exit 1; fi

# Read and validate the complete file before modifying the system.
# Supported dialect: four unquoted fields, no embedded commas or newlines.
declare -a names=() users=() groups=() emails=()
declare -A seen=()
line_no=0
while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    line=${line%$'\r'}
    if (( line_no == 1 )); then
        line=${line#$'\xef\xbb\xbf'}
        [[ "$line" == "fullname,username,group,email" ]] || {
            echo "Invalid CSV header." >&2; exit 2;
        }
        continue
    fi
    [[ -z "$line" ]] && continue
    commas=${line//[^,]/}
    if [[ ${#commas} != 3 || "$line" == *\"* || "$line" =~ [[:cntrl:]] ]]; then
        echo "Invalid CSV format at line $line_no." >&2; exit 2
    fi
    IFS=, read -r fullname username group email <<< "$line"
    if [[ -z "$fullname" || "$fullname" == *:* ||
          ! "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ||
          ! "$group" =~ ^[a-z_][a-z0-9_-]{0,31}$ ||
          ! "$email" =~ ^[^[:space:]:@]+@[^[:space:]:@]+\.[^[:space:]:@]+$ ]]; then
        echo "Invalid field at line $line_no." >&2; exit 2
    fi
    if [[ -n ${seen[$username]+x} ]]; then
        echo "Duplicate username at line $line_no." >&2; exit 2
    fi
    seen[$username]=1
    # Restrict primary groups to a dedicated lab namespace.
    if [[ ! "$group" =~ ^lab_[a-z0-9_-]+$ ]]; then
        echo "Group must start with lab_ at line $line_no." >&2; exit 2
    fi
    names+=("$fullname"); users+=("$username")
    groups+=("$group"); emails+=("$email")
done < "$1"

if (( line_no == 0 || ${#users[@]} == 0 )); then
    echo "No user records." >&2; exit 2
fi

# Existing accounts are never modified. Refuse pre-existing home paths.
for i in "${!users[@]}"; do
    username=${users[i]}
    group=${groups[i]}
    if getent passwd "$username" >/dev/null; then
        printf 'SKIP existing user: %s\n' "$username"
        continue
    fi
    home="/home/$username"
    if [[ -e "$home" || -L "$home" ]]; then
        printf 'Refusing existing home path: %s\n' "$home" >&2
        exit 1
    fi
    printf '%s user=%s group=%s home=%s\n' "$(if ((apply)); then echo CREATE; else echo PLAN; fi)" "$username" "$group" "$home"
    if (( apply )); then
        if ! getent group "$group" >/dev/null; then
            groupadd -- "$group"
        fi
        useradd -m -d "$home" -s /bin/bash -g "$group" \
            -c "${names[i]} (${emails[i]})" -- "$username"
        # useradd without -p creates a locked password by default.
        printf 'Created %s; set password separately using passwd.\n' "$username"
    fi
done
if (( ! apply )); then echo "Dry-run complete. No changes made."; fi
