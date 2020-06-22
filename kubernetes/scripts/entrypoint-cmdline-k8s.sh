#!/bin/bash

# Copyright (c) 2020. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

# Wraps the jasperserver-pro-cmdline entrypoint.sh to 
# manage keystore files in a secret

. ./common-environment-k8s.sh

BASE_ENTRYPOINT=${BASE_ENTRYPOINT:-/entrypoint-cmdline.sh}

initialize_keystore_files_from_secret

( ${BASE_ENTRYPOINT} "$@" )

save_jrsks_to_secret
