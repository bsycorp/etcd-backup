#!/usr/bin/env bash

set -eufo pipefail

function check_commands() {
  for cmd in curl jq aws; do
    if ! command -v ${cmd} >/dev/null 2>/dev/null; then
      echo >&2 "Missing command: ${cmd}"
      exit 1
    fi
  done
}

function get_volume_id() {
  case $VOLUME in
    main)   export device="/dev/xvdu";;
    events) export device="/dev/xvdv";;
    *)      echo >&2 "First argument must be 'main' or 'events'"; exit 1;;
  esac

  VOLUME_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=${INSTANCE_NAME} --region ${AWS_REGION} | jq -r '.Reservations[0].Instances[0].BlockDeviceMappings[] | select(.DeviceName == "'${device}'") | .Ebs.VolumeId')
  [ -z "${VOLUME_ID}" ] && echo >&2 "Error getting volume-id" && exit 1
  return 0
}

function take_snapshot() {
  echo "$0: Creating snapshot of '${VOLUME_ID}'"
  local snapshot_id=$(aws ec2 create-snapshot --volume-id ${VOLUME_ID} --description "Automatic snapshot by ${HOSTNAME}" --region ${AWS_REGION} | jq -r .SnapshotId)

  echo "$0: Tagging snapshot '${snapshot_id}'"
  aws ec2 describe-tags --filters "Name=resource-id,Values=${VOLUME_ID}" --output json --region ${AWS_REGION} | jq '[.Tags[] | {"Key": .Key, "Value": .Value}] | {"DryRun": false, "Resources": ["'${snapshot_id}'"], "Tags": .}' > /tmp/tags.json
  aws ec2 create-tags --region=${AWS_REGION} --cli-input-json file:///tmp/tags.json

  rm -f /tmp/tags.json || true
}

function expire_snapshot() {
  if [ -z ${SNAPSHOT_RETENTION+x} ] || [ -z "${SNAPSHOT_RETENTION}" ]; then
    SNAPSHOT_RETENTION=6
  fi

  local snapshot_count=$(aws ec2 describe-snapshots --filters "Name=volume-id,Values=${VOLUME_ID}" --region ${AWS_REGION} | jq -r '.Snapshots | length')
  
  if [ $snapshot_count -gt $SNAPSHOT_RETENTION ]; then
    local snapshot_ids=$(aws ec2 describe-snapshots --filters "Name=volume-id,Values=${VOLUME_ID}" --region ${AWS_REGION} | jq -r ".Snapshots[$SNAPSHOT_RETENTION:][].SnapshotId")
    echo "Snapshots to delete: $snapshot_ids"

    for id in $snapshot_ids; do
      echo "Deleting snapshot $id"
      aws ec2 delete-snapshot --snapshot-id $id --region ${AWS_REGION}
    done
  fi
}

check_commands
get_volume_id
take_snapshot
expire_snapshot

