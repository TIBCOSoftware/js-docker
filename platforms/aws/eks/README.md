# TIBCO JasperReports&reg; Server with Amazon EKS

# Table of contents
1. [Introduction](#introduction)
1. [Prerequisites](#prerequisites)
1. [EKS Cluster setup](#eks-cluster-setup)

# Introduction
 These EKS configuration files help to create a EKS cluster setup.

# Prerequisites
The following software's are required 
- AWS Account
- AWS administrative access. To manage:
  - EKS
  - run CloudFormation templates
- Instsall required software's and tools , see here for [eksctl ,kubectl and aws cli setup and configuration](https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html)

# EKS Cluster setup
 To Setup a EKS cluster run below command .
 `eksctl create cluster -f eksclustersetup.yaml`. Modify the **eksclustersetup.yaml** file as per the need. 
 It will take 15 to 20 minutes to setup a cluster along the managed node groups. 
 
 By default it will create a cluster with single Node with  two private and two public subnets in a separate VPC.

To verify the cluste setup run `kubectl get svc` and it will list the ClusterIP and it will confirm the cluster is ready.
 
 Once Cluster is ready and see the [Js-Docker/Kubernets](https://github.com/TIBCOSoftware/js-docker/tree/ENGINFRA-8743-K8s-Fix/kubernetes) for JRS deployment in EKS.
 
 Note: It is a basic cluster setup and for advanced security features and some other configuration , refer the [Official AWS Docs](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)


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