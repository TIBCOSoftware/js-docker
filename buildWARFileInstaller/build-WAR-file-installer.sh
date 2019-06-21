#!/bin/sh

ANT_OPTS="-Xms128m -Xmx512m -Djava.net.preferIPv4Stack=true"

#
# setup to use bundled of ant
#


ANT_HOME=./apache-ant
export ANT_HOME
ANT_RUN=$ANT_HOME/bin/ant
export ANT_RUN
PATH=$ANT_HOME/bin:$PATH
export PATH

#
# Collect the command line args
#

CMD_LINE_ARGS=$*

$ANT_RUN --noconfig -nouserlib -f buildWARFileInstaller.xml $CMD_LINE_ARGS

