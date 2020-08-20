#!/bin/bash

# Copyright (c) 2019. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

# Wraps the jasperserver-pro entrypoint.sh to load license and
# other config files from a given S3 bucket

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. $DIR/common-environment-aws.sh

BASE_ENTRYPOINT_PATH=${DIR}/${BASE_ENTRYPOINT:-/entrypoint-cmdline.sh}


case "$1" in
  init)
	createBucketFolder ${S3_DEFAULT_MASTER}
	createBucketFolder ${S3_LICENSE}
	createBucketFolder ${S3_KEYSTORE}
	createBucketFolder ${S3_CUSTOMIZATION}
	createBucketFolder ${S3_BUILDOMATIC_CUSTOMIZATION}
	createBucketFolder ${S3_TOMCAT_CUSTOMIZATION}
	createBucketFolder ${S3_SSL_CERTIFICATE}

    initialize_from_S3

    ( ${BASE_ENTRYPOINT_PATH} "$@" )
    ;;

  import)
    # args are:
    #   mode: s3 or mnt
    #   in-order volumes or A_BUCKET_NAME/folder
    initialize_from_S3
    echo "$@"
    shift 1
    case "$1" in
      s3)
        # in-order A_BUCKET_NAME_1/folder1 A_BUCKET_NAME_2/folder2/import-properties-file
        shift 1
        # copy contents to /tmp/${bucketAndFolder}
        for bucketAndFolder in $@; do
          importFileName="import.properties"

          if aws s3 ls s3://${bucketAndFolder}/${importFileName} ; then
            echo "Loading import from s3: ${bucketAndFolder}"
            mkdir -p /tmp/${bucketAndFolder}
            #aws s3 ls s3://${bucketAndFolder} --recursive
            aws s3 cp s3://${bucketAndFolder} /tmp/${bucketAndFolder} --recursive
            #ls /tmp/${bucketAndFolder}

            ( ${BASE_ENTRYPOINT_PATH} import "/tmp/${bucketAndFolder}/${importFileName}" )

            # copy results back into s3 ${bucketAndFolder}
            aws s3 cp /tmp/${bucketAndFolder} s3://${bucketAndFolder}/ --recursive
            aws s3 rm s3://${bucketAndFolder}/${importFileName}
            rm -rf /tmp/${bucketAndFolder}
          else
            echo "No import.properties in s3://${bucketAndFolder}. Skipping import."
          fi
        done
        for bucketAndFolder in $@; do
        done
        ;;
      mnt)
        shift 1
        ( ${BASE_ENTRYPOINT_PATH} import "$@" )
        ;;
    esac
    ;;

  export)

    # args are:
    #   mode: s3 or mnt
    #   in-order volumes or A_BUCKET_NAME/folder
    initialize_from_S3
    echo "$@"
    shift 1
    case "$1" in
      s3)
        # in-order A_BUCKET_NAME_1/folder1 A_BUCKET_NAME_2/folder2
        shift 1
        command=""
        # copy contents to /tmp/${bucketAndFolder}
        for bucketAndFolder in $@; do
          exportFileName="export.properties"

          if aws s3 ls s3://${bucketAndFolder}/${exportFileName} ; then
            echo "Exporting to s3: ${bucketAndFolder}"
            mkdir -p /tmp/${bucketAndFolder}
            aws s3 cp s3://${bucketAndFolder}/${exportFileName} /tmp/${bucketAndFolder}
            ( ${BASE_ENTRYPOINT_PATH} export "/tmp/${bucketAndFolder}/${exportFileName}" )
            # copy export results into ${bucketAndFolder}
            aws s3 cp /tmp/${bucketAndFolder} s3://${bucketAndFolder} --recursive
            aws s3 rm s3://${bucketAndFolder}/${exportFileName}
            rm -rf /tmp/${bucketAndFolder}
          else
            echo "No export.properties in s3://${bucketAndFolder}. Skipping export."
          fi
        done
        ;;
      mnt)
        shift 1
        ( ${BASE_ENTRYPOINT_PATH} export "$@" )
        ;;
    esac
    ;;
  *)
    exec "$@"
esac

save_jrsks_to_S3
