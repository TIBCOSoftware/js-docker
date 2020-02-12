#!/bin/bash
set -e
# assumes user running this script has:
#   - sudo permissions to install docker if it not there
#   - AWS role permissions to interact with ECR and push images to it

region=""
regionParameter=""
profile=""
account_id=""
version='7.5.0'

for ARGUMENT in "$@"
do
    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE=$(echo $ARGUMENT | cut -f2 -d=)   

    case "$KEY" in
            region)
			region="${VALUE}"
			regionParameter="--${KEY} ${VALUE}"
			;;

            profile)
			profile="--${KEY} ${VALUE}" ;;     

            account_id)
			account_id="${VALUE}" ;;     

            version)
			version="${VALUE}" ;;     

            *)
			echo "Unknown argument: ${ARGUMENT}. ignoring"
    esac
done

# arguments:
# account_id=<AWS account id> required
# region=<an AWS region> ie. us-west-2. required
# profile=<a AWS user profile>  (optional)
# version=<JasperReports Server version>. optional. defaults to 7.5.0

if [ -z "$account_id" ]; then
  echo "account_id required. exiting"
  exit 0
fi

if [ -z "$region" ]; then
  echo "region required. exiting"
  exit 0
fi

if [[ ! $(systemctl list-units --full -all | grep "docker.service") ]]; then
  sudo yum update
  sudo yum -y install docker unzip
  sudo service docker start
  sudo usermod -aG docker $USER
fi


JasperReportsServerVersion=$version

docker build -f Dockerfile --build-arg HTTP_PORT=80 --build-arg HTTPS_PORT=443 -t jasperserver-pro:${JasperReportsServerVersion} .
docker build -f Dockerfile-cmdline -t jasperserver-pro-cmdline:${JasperReportsServerVersion} .

#cd kubernetes
#docker build -f Dockerfile-cmdline-k8s --build-arg JasperReportsServerVersion=${JasperReportsServerVersion} -t jasperserver-pro-cmdline:k8s-${JasperReportsServerVersion} .

#cd ../platforms/aws
#docker build -f Dockerfile-s3 --build-arg JasperReportsServerVersion=${JasperReportsServerVersion} -t jasperserver-pro:s3-${JasperReportsServerVersion} .
#docker build -f Dockerfile-cmdline-s3 --build-arg JasperReportsServerVersion=${JasperReportsServerVersion} -t jasperserver-pro-cmdline:s3-${JasperReportsServerVersion} .
      
echo 'ECR login...'
$(aws ecr get-login $region_parameter $profile --no-include-email)
echo 'Create image repositories ...'
if aws ecr describe-repositories $region_parameter $profile --repository-names jasperserver-pro | grep repositoryUri; then
  echo 'jasperserver-pro ECR Repository already exists, skipping repository creation...'
else 
  echo 'jasperserver-pro ECR Repository does not exist, creating...'
  aws ecr create-repository $region_parameter $profile --repository-name jasperserver-pro
fi

if aws ecr describe-repositories $region_parameter $profile --repository-names jasperserver-pro-cmdline | grep repositoryUri; then
  echo 'jasperserver-pro-cmdline ECR Repository already exists, skipping repository creation...'
else 
  echo 'jasperserver-pro-cmdline ECR Repository does not exist, creating...'
  aws ecr create-repository $region_parameter_parameter $profile --repository-name jasperserver-pro-cmdline
fi
      
echo 'Tagging and pushing to ECR...'
      
docker tag jasperserver-pro:${JasperReportsServerVersion} ${account_id}.dkr.ecr.${region}.amazonaws.com/jasperserver-pro:${JasperReportsServerVersion}
docker tag jasperserver-pro-cmdline:${JasperReportsServerVersion} ${account_id}.dkr.ecr.${region}.amazonaws.com/jasperserver-pro-cmdline:${JasperReportsServerVersion}
docker tag jasperserver-pro-cmdline:k8s-${JasperReportsServerVersion} ${account_id}.dkr.ecr.${region}.amazonaws.com/jasperserver-pro-cmdline:k8s-${JasperReportsServerVersion}
docker tag jasperserver-pro:s3-${JasperReportsServerVersion} ${account_id}.dkr.ecr.${region}.amazonaws.com/jasperserver-pro:s3-${JasperReportsServerVersion}
docker tag jasperserver-pro-cmdline:s3-${JasperReportsServerVersion} ${account_id}.dkr.ecr.${region}.amazonaws.com/jasperserver-pro-cmdline:s3-${JasperReportsServerVersion}
                    
docker push ${account_id}.dkr.ecr.${region}.amazonaws.com/jasperserver-pro:${JasperReportsServerVersion}
docker push ${account_id}.dkr.ecr.${region}.amazonaws.com/jasperserver-pro-cmdline:${JasperReportsServerVersion}
docker push ${account_id}.dkr.ecr.${region}.amazonaws.com/jasperserver-pro-cmdline:k8s-${JasperReportsServerVersion}
docker push ${account_id}.dkr.ecr.${region}.amazonaws.com/jasperserver-pro:s3-${JasperReportsServerVersion}
docker push ${account_id}.dkr.ecr.${region}.amazonaws.com/jasperserver-pro-cmdline:s3-${JasperReportsServerVersion}

