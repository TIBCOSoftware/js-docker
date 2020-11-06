# TIBCO JasperReports&reg; Server with Amazon EKS

# Table of contents
1. [Introduction](#introduction)
1. [Prerequisites](#prerequisites)
1. [EKS Cluster setup](#eks-cluster-setup)
1. [EFS Configuration for applying the customization](#efs-setup-for-customization)
# Introduction
 These EKS configuration files help to create a EKS cluster setup.

# Prerequisites
The following software's are required 
- AWS Account
- AWS administrative access. To manage:
  - EKS
  - Run CloudFormation templates
- Instsall required software's and tools , see here for [eksctl ,kubectl and aws cli setup and configuration](https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html)

# EKS Cluster setup
 To Setup a EKS cluster run below command .
 
 `eksctl create cluster -f eksclustersetup.yaml`. Modify the **eksclustersetup.yaml** file as per the need. 
 It will take 15 to 20 minutes to setup a cluster along with the managed node groups. 
 
 By default it will create a cluster with single Node with  two private and two public subnets in a separate VPC.

To verify the cluste setup run `kubectl get svc` and it will list the ClusterIP and it will confirm that the cluster is ready.
 
 Once Cluster is ready and see the [Js-Docker/Kubernets](https://github.com/TIBCOSoftware/js-docker/tree/master/kubernetes) for JRS deployment in EKS.
 
 Note: It is a basic cluster setup and for advanced security features and some other configuration , refer the [Official AWS Docs](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)

# EFS Configuration for applying the customization
   For large amount of files for customizations in kubernetes deployment , kubernetes secrets may not work. To avoid such type of issues , 
we can use AWS EFS CSI driver for mounting the larger amount of data and same data can be deployed in Jaspersoft.
To Setup EFS Storage for EKS cluster follow below steps.

- To install EFS CSI driver in EKS cluster and creating EFS in aws follow this [AWS-CSI-DRIVER](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html)
Make sure EFS should be created in same VPC where EKS cluster is created and allow NFS port for EKS cluster CIDR range
- Once everything setup run `aws efs describe-file-systems --query "FileSystems[*].FileSystemId" --output text` to get the EFS file system ID or get the ID aws console
- modify the `eks-efs-setup.yaml` and replace the volumeHandle  with EFS file system ID
 ````
      csi:
        driver: efs.csi.aws.com
        volumeHandle: fs-xxxxx`    
````
- Create jaspersoft name space in kubernetes cluster by running `kubectl apply -f namespace-rbac.yaml` , find the namespace-rbac-yaml file [js-docker/kubernetes](https://github.com/TIBCOSoftware/js-docker/tree/master/kubernetes)
- Create Kubernets storage , persistent volume and persistent volume claim in EKS cluster by running `kubectl apply -f eks-efs-setup.yaml`
- Remove the jasperserver-pro-volume in [Kubernetes-deployment-yaml-file](https://github.com/TIBCOSoftware/js-docker/blob/master/kubernetes/jasperreports-server-service-deployment.yaml)
and add below volume in volumes sections .
````
- name: jasperserver-pro-volume
  persistentVolumeClaim:
     claimName: jaspersoft-efs-claim
````
- To mount the data from on-premises to EFS , first create ec2 instance on same VPC where eks cluster is created and allow SSH port to copy the data
- Connect to ec2 instance , switch to root user and create efs directory `mkdir efs` 
- Mount EFS on ec2 machine bu running EFS mount point similar t0 like this `sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-XXXX.efs.us-east-1.amazonaws.com:/ efs`.
- To get the EFS mount point , click in EFS which is created and click on attach button and then will see EFS mount options, copy the EFS mount point from `Using the NFS client:` and run it on ec2 machine.
- For more information follow [Mount EFS on EC2 machine](https://docs.aws.amazon.com/efs/latest/ug/wt1-test.html)
- Copy all your customizations in proper volumes , see [JS-Docker-volumes](https://github.com/TIBCOSoftware/js-docker#jasperreports-server-volumes)

 Once Everything is setup then see the [Js-Docker/Kubernets](https://github.com/TIBCOSoftware/js-docker/tree/master/kubernetes) for JRS deployment in EKS.

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