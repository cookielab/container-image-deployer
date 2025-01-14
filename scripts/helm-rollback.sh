#!/bin/bash

export RELEASE=$(echo "${HELM_RELEASE_NAME:0:36}" | sed -E 's/-+$//')

FAILED=$(helm list --failed -n $KUBE_NAMESPACE | grep  ^${RELEASE}\\s | wc -l )
PENDING=$(helm list --pending -n $KUBE_NAMESPACE | grep  ^${RELEASE}\\s | wc -l)

if [ "$PENDING" -gt 0 ]; then
  echo "Pending release found."
  helm list --pending -n $KUBE_NAMESPACE
  echo "Waiting for 15 minutes ..."
  for i in $(seq 1 15); do
    sleep 60
    echo "Still wating for $i minutes"
    PENDING=$(helm list --pending -n $KUBE_NAMESPACE | grep  ^${RELEASE}\\s | wc -l)
    if [ "$PENDING" -eq 0 ]; then
      break
    fi
  done
fi

FAILED=$(helm list --failed -n $KUBE_NAMESPACE | grep  ^${RELEASE}\\s | wc -l )
PENDING=$(helm list --pending -n $KUBE_NAMESPACE | grep  ^${RELEASE}\\s | wc -l)

if [ "$PENDING" -gt 0 -o "$FAILED" -gt 0 ]; then
  echo "Pending or failed release found."
  helm list --failed --pending -n $KUBE_NAMESPACE
  export LAST=$(helm list --failed --pending -n $KUBE_NAMESPACE | grep  ^${RELEASE}\\s | awk '{print $3-1}')
  echo "Rolling back to ${LAST}..."
  helm rollback $RELEASE $LAST -n $KUBE_NAMESPACE
else
  echo "No pending/failed release, go ahead."
fi
