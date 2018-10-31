# Introduction

[![Build Status](https://travis-ci.org/bsycorp/etcd-backup.svg?branch=master)](https://travis-ci.org/bsycorp/etcd-backup)

This is a Kubernetes cron job that takes a snapshot of our etcd EBS volumes every hour. And expires the snapshots with reasonable retention.

We make backups of the etcd block-device, not the etcd data-directory. This means that we can *only* restore etcd in its entirety and not partially.

# Installation

### IAM role

Create an IAM role with with the following permissions:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:CreateSnapshot",
                "ec2:DeleteSnapshot",
                "ec2:DescribeSnapshots",
                "ec2:DescribeVolumes",
                "ec2:DescribeTags",
                "ec2:CreateTags"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
```

Specify a Kube2iam annotation to attach the role to the job pod via kube2iam or kiam:
```
iam.amazonaws.com/role: cluster-k8s-etcd-backup
```

### Install the Kubernetes Cron Job

```
kubectl apply -f kubernetes/etcd-backup-cron.yaml
```

### Configuration

Specify settings in kube manifest:
```
- name: INSTANCE_NAME
  value: master.cluster.example
- name: VOLUME
  value: main
- name: AWS_REGION
  value: ap-southeast-2
- name: SNAPSHOT_RETENTION
  value: "6"
```

# Restore etcd from snapshots

**THIS WILL CAUSE DOWNTIME**

* Select the snapshots to restore
* Set the desired and minimum replicas of the master ASGs to 0
* Delete the existing volumes
* Create volumes from the snapshots and copy the tags over
  * Make sure you create the volumes in the right availability-zone
* Set the desired and minimum replicas of the master ASGs to 1

### Caveats

When you create new volumes from your snapshots the previously created snapshots will no longer be expired automatically. Delete these manually.

