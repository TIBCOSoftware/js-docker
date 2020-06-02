#!/bin/bash
#
# script to run import command
#

BASEDIR=$(dirname $0);export BASEDIR

JS_EXP_CMD_CLASS=com.jaspersoft.jasperserver.export.ImportCommand
export JS_EXP_CMD_CLASS

JS_CMD_NAME=$0
export JS_CMD_NAME

export ANT_ARGS="$ANT_ARGS -q -emacs -logger com.jaspersoft.buildomatic.ImportExportLogger -lib target"

$BASEDIR/js-ant "validate-database validate-keystore"

if [ $? -eq 0 ];
then
  $BASEDIR/bin/js-import-export.sh $*
fi


