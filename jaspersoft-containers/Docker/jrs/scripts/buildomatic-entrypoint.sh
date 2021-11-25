#! /bin/bash

# Copyright (c) 2021-2021. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file

set -e
cat >> default_master.properties \
<<-_EOL_
appServerType=skipAppServerCheck
_EOL_

./js-ant "$@"