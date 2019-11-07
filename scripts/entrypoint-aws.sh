#!/bin/bash

# Copyright (c) 2019. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

# Wraps the jasperserver-pro entrypoint.sh to load license and
# other config files from a given S3 bucket

MOUNTS_HOME=${MOUNTS_HOME:-/usr/local/share/jasperserver-pro}
S3_BUCKET_NAME=${S3_BUCKET_NAME:-jasperserver-pro}

initialize_from_S3() {
  mkdir ${MOUNTS_HOME}

  if aws s3 ls s3://${S3_BUCKET_NAME}; then
    echo "S3 Bucket ${S3_BUCKET_NAME} exists and has contents. Loading..."
  else
    echo "S3 bucket ${S3_BUCKET_NAME} does not exist or is empty. Not loading..."
    return
  fi
  
  # get default_master/default_master_additional.properties into /usr/local/share/jasperserver-pro/deploy-customization
  
  if aws s3 ls s3://${S3_BUCKET_NAME}/default-master/default_master_additional.properties ; then
    aws s3 cp s3://${S3_BUCKET_NAME}/default-master/default_master_additional.properties ${MOUNTS_HOME}/default_master/default_master_additional.properties
  fi
  
  # get license/jasperserver.license into /usr/local/share/jasperserver-pro/license
  if aws s3 ls s3://${S3_BUCKET_NAME}/license/jasperserver.license ; then
    aws s3 cp s3://${S3_BUCKET_NAME}/license/jasperserver.license ${MOUNTS_HOME}/license/jasperserver.license
  fi

  # get keystore/.keystore into ${MOUNTS_HOME}/keystore
  if aws s3 ls s3://${S3_BUCKET_NAME}/keystore/.keystore ; then
    aws s3 cp s3://${S3_BUCKET_NAME}/keystore/.keystore ${MOUNTS_HOME}/keystore/.keystore
  fi
 
  # get list of JRS customization zips into ${MOUNTS_HOME}/customization
  if aws s3 ls s3://${S3_BUCKET_NAME}/customization --recursive ; then
    aws s3 cp s3://${S3_BUCKET_NAME}/customization ${MOUNTS_HOME}/customization --recursive
  fi

  # get list of Tomcat customization zips into ${MOUNTS_HOME}/tomcat-customization
  if aws s3 ls s3://${S3_BUCKET_NAME}/tomcat-customization --recursive ; then
    aws s3 cp s3://${S3_BUCKET_NAME}/tomcat-customization ${MOUNTS_HOME}/tomcat-customization --recursive
  fi
}

initialize_from_S3
BASE_ENTRYPOINT=${BASE_ENTRYPOINT:-/entrypoint.sh}

case "$1" in
  run)
    ( ${BASE_ENTRYPOINT} "$@" )
    ;;
  init)
    ( ${BASE_ENTRYPOINT} "$@" )
    ;;
  import)

    # args are:
    #   mode: s3 or mnt
    #   in-order volumes or A_BUCKET_NAME/folder
    echo "$@"
    shift 1
    case "$1" in
      s3)
        # in-order A_BUCKET_NAME_1/folder1 A_BUCKET_NAME_2/folder2
        shift 1
        command=""
        # copy contents to /tmp/${bucketAndFolder}
        for bucketAndFolder in $@; do
          if aws s3 ls s3://${bucketAndFolder}/import.properties ; then
            echo "Loading import from s3: ${bucketAndFolder}"
            mkdir -p /tmp/${bucketAndFolder}
            aws s3 ls s3://${bucketAndFolder} --recursive
            aws s3 cp s3://${bucketAndFolder} /tmp/${bucketAndFolder} --recursive
            ls /tmp/${bucketAndFolder}
            command="${command} /tmp/${bucketAndFolder}"
          fi
        done
        ( ${BASE_ENTRYPOINT} import "${command}" )
        # copy results back into ${bucketAndFolder}
        for bucketAndFolder in $@; do
          if test -f "/tmp/${bucketAndFolder}/import-done.properties" ; then
            aws s3 cp /tmp/${bucketAndFolder}/import-done.properties s3://${bucketAndFolder}/
            aws s3 rm s3://${bucketAndFolder}/import.properties
            rm -rf /tmp/${bucketAndFolder}
         fi
        done
        ;;
      mnt)
        shift 1
        ( ${BASE_ENTRYPOINT} import "$@" )
        ;;
    esac
    ;;

  export)

    # export: args are in-order EXPORT_S3_BUCKET_NAME/folder
    # copy contents to /tmp/EXPORT_S3_BUCKET_NAME/folder
    ( ${BASE_ENTRYPOINT} "$@" )
    # copy results back into EXPORT_S3_BUCKET_NAME/folder

    # args are:
    #   mode: s3 or mnt
    #   in-order volumes or A_BUCKET_NAME/folder
    echo "$@"
    shift 1
    case "$1" in
      s3)
        # in-order A_BUCKET_NAME_1/folder1 A_BUCKET_NAME_2/folder2
        shift 1
        command=""
        # copy contents to /tmp/${bucketAndFolder}
        for bucketAndFolder in $@; do
          if aws s3 ls s3://${bucketAndFolder}/export.properties ; then
            echo "Exporting to s3: ${bucketAndFolder}"
            mkdir -p /tmp/${bucketAndFolder}
            aws s3 cp s3://${bucketAndFolder}/export.properties /tmp/${bucketAndFolder}/export.properties
            command="${command} /tmp/${bucketAndFolder}"
          fi
        done
        ( ${BASE_ENTRYPOINT} export "${command}" )
        # copy export results into ${bucketAndFolder}
        for bucketAndFolder in $@; do
          if test -f "/tmp/${bucketAndFolder}/export-done.properties" ; then
            aws s3 cp /tmp/${bucketAndFolder} s3://${bucketAndFolder}/ --recursive
            aws s3 rm s3://${bucketAndFolder}/export.properties
            rm -rf /tmp/${bucketAndFolder}
         fi
        done
        ;;
      mnt)
        shift 1
        ( ${BASE_ENTRYPOINT} export "$@" )
        ;;
    esac
    ;;
  *)
    exec "$@"
esac
