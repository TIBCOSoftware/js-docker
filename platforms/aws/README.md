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
- jasperserver-pro:<version>
- jasperserver-pro-cmdline:<version>
- jasperserver-pro-cmdline:<version>-k8s

To create these stacks, you need to go to the AWS Marketplace and subscribe to TIBCO Jaspersoft Reporting and Analytics (BYOL).
- Find via the listings via: https://aws.amazon.com/marketplace/search/results?x=0&y=0&searchTerms=jaspersoft+byol
- Login to your AWS account as a user with the ability to subscribe to Marketplace listings.
- Continue to Subscribe
- Accept terms and conditions
- Do not launch instances

Create a stack for the desired version of JasperReports Server, based on the templates here. These templates:
- Launch a JasperReports Server BYOL instance
- Install Docker
- Download the master branch of https://github.com/TIBCOSoftware/js-docker
- Build 
  - jasperserver-pro:<version>
  - jasperserver-pro-cmdline:<version>
  - jasperserver-pro-cmdline:<version>-k8s
    - note that the JasperReports Server image is confiured to run on port 80 in the template
- Create ECR repositories for the current AWS account and region if they do not exist
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
