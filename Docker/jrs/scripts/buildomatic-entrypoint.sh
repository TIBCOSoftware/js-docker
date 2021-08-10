#! /bin/bash
set -e
cat >> default_master.properties \
<<-_EOL_
appServerType=skipAppServerCheck
_EOL_

./js-ant "$@"