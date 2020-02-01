#!/bin/bash

# Copyright (c) 2019. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

# Wraps the jasperserver-pro-cmdline entrypoint.sh to 
# maintain keystore files in secrets

MOUNTS_HOME=${MOUNTS_HOME:-/usr/local/share/jasperserver-pro}
SECRET_MOUNTS_HOME=${SECRET_MOUNTS_HOME:-/usr/local/share/jasperserver-pro-secrets}

KEYSTORE_SECRET_NAME=${KEYSTORE_SECRET_NAME:-jasperserver-pro-jrsks}

SECRET_JRSKS_REQUIRED=false
JRSKS_ORIG_DATE=xxx

# keystore files in a secret get moved into keystore mount if they are there

initialize_keystore_files_from_secret() {
  if [ ! -f ${SECRET_MOUNTS_HOME}/${KEYSTORE_SECRET_NAME}/.jrsks ] ; then
    echo "Cmdline: No jrsks in secret ${KEYSTORE_SECRET_NAME} - will have to create from generated .jrsks"
    SECRET_JRSKS_REQUIRED=true
  else
    # already have the jrsks file in the mounted file system
    # get secret .jrsks and .jrsksp into ${MOUNTS_HOME}/keystore
    echo "Cmdline: Using jrsks in secret ${KEYSTORE_SECRET_NAME}"
    if [ ! -d ${MOUNTS_HOME}/keystore ] ; then
      mkdir ${MOUNTS_HOME}/keystore
    fi
    cp ${SECRET_MOUNTS_HOME}/${KEYSTORE_SECRET_NAME}/.jrsks ${MOUNTS_HOME}/keystore
    cp ${SECRET_MOUNTS_HOME}/${KEYSTORE_SECRET_NAME}/.jrsksp ${MOUNTS_HOME}/keystore
    JRSKS_ORIG_DATE="$(ls -l ${MOUNTS_HOME}/keystore/.jrsksp | awk '{print $6 $7 $8}')"
    # echo ".jrsksp original date: $JRSKS_ORIG_DATE"
  fi
}

# write back jrsks files to a secret, if they have been created or changed.
# leave the jrsks files in the ${MOUNTS_HOME}/keystore for downstream use
save_jrsks_to_secret() {
  JRSKS_NEW_DATE="$(ls -l ${MOUNTS_HOME}/keystore/.jrsksp | awk '{print $6 $7 $8}')"
  # echo "after cmdline: .jrsksp new date <$JRSKS_NEW_DATE>"
  if [ "$SECRET_JRSKS_REQUIRED" = "true" -o ! "$JRSKS_ORIG_DATE" = "$JRSKS_NEW_DATE" ] ; then
    echo "Cmdline: saving .jrsks and .jrsksp to secret $KEYSTORE_SECRET_NAME"
    newks="$( cat ${MOUNTS_HOME}/keystore/.jrsks | base64 )"
    newksp="$( cat ${MOUNTS_HOME}/keystore/.jrsksp | base64 )"
    kubectl get secret ${KEYSTORE_SECRET_NAME} -o json | jq --arg jrsks "$newks" '.data[".jrsks"]=$jrsks' | \
        jq --arg jrsksp "$newksp" '.data[".jrsksp"]=$jrsksp' | kubectl apply -f -
  else
    echo "Cmdline: Not updating .jrsks secret"
  fi
}
