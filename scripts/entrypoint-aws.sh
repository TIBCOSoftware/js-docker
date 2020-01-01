#!/bin/bash

# Copyright (c) 2019. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

# Wraps the jasperserver-pro entrypoint.sh to load license and
# other config files from a given S3 bucket

. ./common-environment-aws.sh

initialize_from_S3
BASE_ENTRYPOINT=${BASE_ENTRYPOINT:-/entrypoint.sh}

case "$1" in
  run)
    ( ${BASE_ENTRYPOINT} "$@" )
    ;;

  *)
    exec "$@"
esac

# jrsks is updated only via the cmdline processes

# save_jrsks_to_S3
