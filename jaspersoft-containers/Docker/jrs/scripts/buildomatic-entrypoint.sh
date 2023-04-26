#! /bin/bash

# Copyright © 2021-2023. Cloud Software Group, Inc. All Rights Reserved. Confidential & Proprietary.
# This file is subject to the license terms contained
# in the license file that is distributed with this file

set -e
cat >> default_master.properties \
<<-_EOL_
appServerType=skipAppServerCheck
_EOL_

./js-ant "$@"