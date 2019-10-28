#!/bin/bash

# Copyright (c) 2019. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

# Wraps the jasperserver-pro entrypoint.sh to load license and
# other config files from a given S3 bucket


initialize_from_S3() {
  mkdir /usr/local/share/jasperserver-pro

  S3_BUCKET_NAME=${S3_BUCKET_NAME:-jasperserver-pro}
  if aws s3 ls s3://${S3_BUCKET_NAME}; then
    echo "S3 Bucket ${S3_BUCKET_NAME} exists and has contents. Loading..."
  else
    echo "S3 bucket ${S3_BUCKET_NAME} does not exist or is empty. Not loading..."
    return
  fi
  
  # get default_master/default_master_additional.properties into /usr/local/share/jasperserver-pro/deploy-customization
  
  if aws s3 ls s3://${S3_BUCKET_NAME}/default_master/default_master_additional.properties ; then
    aws s3 cp s3://${S3_BUCKET_NAME}/default_master/default_master_additional.properties /usr/local/share/jasperserver-pro/deploy-customization/default_master_additional.properties
  fi
  
  # get license/jasperserver.license into /usr/local/share/jasperserver-pro/license
  if aws s3 ls s3://${S3_BUCKET_NAME}/license/jasperserver.license ; then
    aws s3 cp s3://${S3_BUCKET_NAME}/license/jasperserver.license /usr/local/share/jasperserver-pro/license/jasperserver.license
  fi

  # get keystore/.keystore into /usr/local/share/jasperserver-pro/keystore
  if aws s3 ls s3://${S3_BUCKET_NAME}/keystore/.keystore ; then
    aws s3 cp s3://${S3_BUCKET_NAME}/keystore/.keystore /usr/local/share/jasperserver-pro/keystore/.keystore
  fi
 
  # get list of JRS customization zips into /usr/local/share/jasperserver-pro/customization
  if aws s3 ls s3://${S3_BUCKET_NAME}/customization --recursive ; then
    aws s3 cp s3://${S3_BUCKET_NAME}/customization --recursive /usr/local/share/jasperserver-pro/customization
  fi

  # get list of Tomcat customization zips into /usr/local/share/jasperserver-pro/tomcat-customization
  if aws s3 ls s3://${S3_BUCKET_NAME}/tomcat-customization --recursive ; then
    aws s3 cp s3://${S3_BUCKET_NAME}/tomcat-customization --recursive /usr/local/share/jasperserver-pro/tomcat-customization
  fi

}

# what about import and export?
# expect that they would be working with the S3 bucket too!

initialize_from_S3

case "$1" in
  run)
    ( /entrypoint.sh "$@" )
    ;;
  init)
    ( /entrypoint.sh "$@" )
    ;;
  import)
    ( /entrypoint.sh "$@" )
    ;;
  export)
    ( /entrypoint.sh "$@" )
    ;;
  *)
    exec "$@"
esac
