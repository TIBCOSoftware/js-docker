# TIBCO JasperReports&reg; Server with Amazon EKS

# Table of contents

1. [Introduction](#introduction)
1. [Prerequisites](#prerequisites)
1. [Install JasperReports Server images into AWS ECR](#install-jasperreports-server-images-into-AWS-ECR)
1. [Deployment to EKS](#deployment-to-eks)

# Introduction

These EKS configurations leverage images created via [https://github.com/TIBCOSoftware/js-docker](#https://github.com/TIBCOSoftware/js-docker)
and configuration options for the JasperReports Server containers are defined there.

You must change the environment variables and declarative configuration to fit with your deployment environment,
such as the platform - Docker for Windows/Mac, Minikube, Amazon EKS, Azure AKS, ... -
and how you want to deploy JasperReports Server:
- exposed to the outside world directly: NodePort, Ingress, LoadBalancer
- JasperReports Server repository database location: within or external to Kubernetes
- use of environment variables and volumes
- use of secrets for passwords

This configuration has been certified using
the PostgreSQL 9 database with JasperReports Server 6.4+
and with PostgreSQL 10 for JasperReports Server 7.2+.

Knowledge of Docker, Kubernetes and your infrastructure is required.
For more information about Docker see the
[official documentation for Docker](https://docs.docker.com/).

For more information about JasperReports Server, see the
[Jaspersoft community](http://community.jaspersoft.com/).

# Prerequisites

The following software is required or recommended:

- (*required*) TIBCO Jaspersoft&reg; commercial license.
  - Contact your sales representative for information about licensing.
- AWS Account
- AWS administrative access. To manage:
  - ECR
  - EKS
  - run CloudFormation templates
  - subscribe to AWS Marketplace listings  
- [kubernetes](https://kubernetes.io/) version 1.17 or higher
- Bastion EC2 instance to run kubectl commands
- (*optional*) Preconfigured PostgreSQL database in RDS

# Install JasperReports Server images into AWS ECR

The CloudFormation templates attached here:
- jasperreports-server-7.2.0-ecr.template
- jasperreports-server-7.5.0-ecr.template
- jasperreports-server-7.5.1-ecr.template
- jasperreports-server-7.8.0-ecr.template

create the JasperReports Server images:
- jasperserver-pro:JASPERSERVER_VERSION
- jasperserver-pro-cmdline:JASPERSERVER_VERSION
- jasperserver-pro-cmdline:JASPERSERVER_VERSION-k8s
- jasperserver-pro:s3-JASPERSERVER_VERSION
- jasperserver-pro-cmdline:s3-JASPERSERVER_VERSION

To create these images , take the ECR template as per the required version of Jasper reports server
- Login to your AWS account 
- Upload the jasperreports-server-<version>-ecr.template template
- Provide the correct github branch url for JaspersoftForDockerURL
- fill all other parameters as per the requirement 
- click create stack 

Once stack creation completed , it will generate docker images in ECR repository in your account

Repository Names:
- jasperserver-pro
- jasperserver-pro-cmdline

Create ECR repositories for the current AWS account and region if they do not exist
  - aws ecr create-repository --region ${AWS::Region} --repository-name jasperserver-pro
  - aws ecr create-repository --region ${AWS::Region} --repository-name jasperserver-pro-cmdline
- Tag and push the versions of the images to the ECR repositories

# Deployment to EKS

General deployment into EKS is documented here: https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html

JasperReports Server deploys into EKS as per the instructions for Kubernetes [js-docker for Kubernetes](https://github.com/TIBCOSoftware/js-docker/tree/master/kubernetes)


# Copyright
Copyright &copy; 2020. TIBCO Software Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
___

TIBCO, Jaspersoft, and JasperReports are trademarks or
registered trademarks of TIBCO Software Inc.
in the United States and/or other countries.

Docker is a trademark or registered trademark of Docker, Inc.
in the United States and/or other countries.
