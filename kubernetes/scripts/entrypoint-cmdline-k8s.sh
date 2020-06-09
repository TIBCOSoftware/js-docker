#!/bin/bash

# Copyright (c) 2020. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

# Wraps the jasperserver-pro-cmdline entrypoint.sh to 
# manage keystore files in a secret

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. $DIR/common-environment-k8s.sh

BASE_ENTRYPOINT_PATH=${DIR}/${BASE_ENTRYPOINT:-/entrypoint.sh}

initialize_keystore_files_from_secret

( ${BASE_ENTRYPOINT_PATH} "$@" )

save_jrsks_to_secret
