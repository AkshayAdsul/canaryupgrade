#!/bin/sh

set -e
set -o pipefail

_filename="$(basename $BASH_SOURCE)"

DEFAULT_NODE_NUM="1"
DEFAULT_REGION="australia-southeast1"
DEFAULT_INSTANCE_TYPE="e2-standard-16"
DEFAULT_CLUSTER_VERSION="1.24"
RES_LABEL_USER="akshay-adsul"
RES_LABEL_END_DATE=`date -j -v+10d +%Y%m%d`
RES_LABEL_APP="gloo-edge"
RES_LABEL_TEAM="fe-postsales"
RES_LABEL_PURPOSE="post-sales"
GCP_PROJECT="solo-test-236622"
NODE_NUM="1"
OWNER="akshay"
CLUSTER_NAME_SUFFIX="akshaygojek"
CLUSTER_VERSION=$DEFAULT_CLUSTER_VERSION
REGION=$DEFAULT_REGION

echo "Creating cluster $OWNER-$CLUSTER_NAME_SUFFIX with $NODE_NUM nodes of type $INSTANCE_TYPE"

gcloud container clusters create "$OWNER-$CLUSTER_NAME_SUFFIX" \
	--project ${GCP_PROJECT} --region "$REGION" \
	--cluster-version "$CLUSTER_VERSION" \
	--labels=team=${RES_LABEL_TEAM},application=${RES_LABEL_APP},purpose=${RES_LABEL_PURPOSE},solo-io_owner=${RES_LABEL_USER},expiration=${RES_LABEL_END_DATE} \
	--machine-type "$DEFAULT_INSTANCE_TYPE" --network "default" --subnetwork "default" \
	--enable-autoscaling --min-nodes "1" --max-nodes "3" \
	--addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
	--enable-autoupgrade --enable-autorepair --enable-ip-alias \
	--max-surge-upgrade 1 --max-unavailable-upgrade 0 --enable-shielded-nodes

