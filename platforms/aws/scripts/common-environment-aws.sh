
#!/bin/bash

# Copyright (c) 2020. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

# Wraps the jasperserver-pro entrypoint.sh to load license and
# other config files from a given S3 bucket

MOUNTS_HOME=${MOUNTS_HOME:-/usr/local/share/jasperserver-pro}

S3_BUCKET_NAME=${S3_BUCKET_NAME:-jasperserver-pro-configuration}

S3_DEFAULT_MASTER=${S3_DEFAULT_MASTER:-$S3_BUCKET_NAME/default-master}
S3_LICENSE=${S3_LICENSE:-$S3_BUCKET_NAME/license}
S3_KEYSTORE=${S3_KEYSTORE:-$S3_BUCKET_NAME/keystore}
S3_CUSTOMIZATION=${S3_CUSTOMIZATION:-$S3_BUCKET_NAME/customization}
S3_TOMCAT_CUSTOMIZATION=${S3_TOMCAT_CUSTOMIZATION:-$S3_BUCKET_NAME/tomcat-customization}
S3_SSL_CERTIFICATE=${S3_SSL_CERTIFICATE:-$S3_BUCKET_NAME/ssl-certificate}

S3_JRSKS_REQUIRED=false
JRSKS_FILES_IN_BUCKET=false
JRSKS_ORIG_DATE=xxx


createBucketFolder() {
    local bucketAndFolder="$1"
    if ! aws s3 ls s3://${bucketAndFolder} ; then
        bucketName="${bucketAndFolder%%*/}"
        folders="${bucketAndFolder#*/}"
        if ! aws s3api get-bucket-location --bucket ${bucketName} | grep LocationConstraint; then
            echo "Creating S3 Bucket ${bucketName} ..."
            aws s3 mb s3://${bucketName}
        fi
        echo "Creating s3://${bucketAndFolder}"
        aws s3api put-object --bucket ${bucketName} --key ${folders}/
    fi
}


initialize_from_S3() {
  mkdir ${MOUNTS_HOME}

  if aws s3 ls s3://${S3_BUCKET_NAME}; then
    echo "S3 Bucket ${S3_BUCKET_NAME} exists and has contents. Loading..."
    S3_JRSKS_REQUIRED=true
  else
    echo "S3 bucket ${S3_BUCKET_NAME} does not exist or is empty. Not loading..."
    return
  fi
  
  # let mounted volume contents override what is in the S3 bucket
  
  # get default_master/default_master_additional.properties into /usr/local/share/jasperserver-pro/default_master
  
  if [[ ! -f ${MOUNTS_HOME}/default_master/default_master_additional.properties && \
    $(aws s3 ls s3://${S3_DEFAULT_MASTER}/default_master_additional.properties) ]] ; then
    aws s3 cp s3://${S3_DEFAULT_MASTER}/default_master_additional.properties ${MOUNTS_HOME}/default_master/default_master_additional.properties
  fi
  
  # get license/jasperserver.license into /usr/local/share/jasperserver-pro/license
  if [[ ! -f ${MOUNTS_HOME}/license/jasperserver.license && $(aws s3 ls s3://${S3_LICENSE}/jasperserver.license) ]] ; then
    aws s3 cp s3://${S3_LICENSE}/jasperserver.license ${MOUNTS_HOME}/license/jasperserver.license
  fi

  # get keystore/.jrsks and .jrsksp into ${MOUNTS_HOME}/keystore
  # the keystore S3 bucket is required
  if [ ! -f ${MOUNTS_HOME}/keystore/.jrsks ] ; then
    S3_JRSKS_REQUIRED=true
    
    if ! aws s3 ls s3://${S3_KEYSTORE} ; then
      createBucketFolder ${S3_KEYSTORE}
    fi
    if aws s3 ls s3://${S3_KEYSTORE}/.jrsks ; then
      aws s3 cp s3://${S3_KEYSTORE} ${MOUNTS_HOME}/keystore --recursive
      JRSKS_FILES_IN_BUCKET=true
      JRSKS_ORIG_DATE="ls -l ${MOUNTS_HOME}/keystore/.jrsks | awk '{print $6 $7 $8}'"
      echo ".jrsks original date: $JRSKS_ORIG_DATE"
    fi
  else
    # already have the jrsks file in the mounted file system
    echo 'Using jrsks in mount'
  fi
 
  # get list of JRS customization zips into ${MOUNTS_HOME}/customization
  if aws s3 ls s3://${S3_CUSTOMIZATION} --recursive ; then
    aws s3 cp s3://${S3_CUSTOMIZATION} ${MOUNTS_HOME}/customization --recursive
  fi

  # get list of Tomcat customization zips into ${MOUNTS_HOME}/tomcat-customization
  if aws s3 ls s3://${S3_TOMCAT_CUSTOMIZATION} --recursive ; then
    aws s3 cp s3://${S3_TOMCAT_CUSTOMIZATION} ${MOUNTS_HOME}/tomcat-customization --recursive
  fi

  # get ssl-certificate/.keystore into ${MOUNTS_HOME}/ssl-certificate
  if aws s3 ls s3://${S3_SSL_CERTIFICATE}/.keystore ; then
    aws s3 cp s3://${S3_SSL_CERTIFICATE}/.keystore ${MOUNTS_HOME}/ssl-certificate/.keystore
  fi
}

# write back jrsks files to the S3 bucket, if they have changed.
# s3 bucket has to have write permissions
save_jrsks_to_S3() {
  JRSKS_NEW_DATE="ls -l ${MOUNTS_HOME}/keystore/.jrsks | awk '{print $6 $7 $8}'"
  echo ".jrsks new date $JRSKS_NEW_DATE"
  if [[ "$S3_JRSKS_REQUIRED" = "true" && "$JRSKS_ORIG_DATE" -ne "$JRSKS_NEW_DATE" ]] ; then
    echo "saving updated .jrsks to ${S3_KEYSTORE}"
    aws s3 cp ${MOUNTS_HOME}/keystore s3://${S3_KEYSTORE} --recursive
  fi
}
