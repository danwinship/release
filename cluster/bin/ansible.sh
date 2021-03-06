#!/bin/bash
set -euo pipefail

platform="$(uname)"

tar_cmd="tar"
tar_opts="--mode=ug+rwX --owner=0 --group=0"
if [ "$platform" == "Darwin" ]; then
    if [ "$(command -v gtar)" != "" ]; then
        tar_cmd="gtar"
    else
        echo "Detected OS as Mac OS, please install gnu-tar (gtar)"
        exit 1
    fi
fi

ctr=gce-build-"$( date +%Y%m%d-%H%M%S )"

function cleanup() {
  docker kill $ctr &>/dev/null || true
  docker rm $ctr &>/dev/null || true
}
trap cleanup EXIT
cleanup

args=""

if [[ $# -eq 0 ]]; then
  args+="-it "
  docker create --name "$ctr" -v /var/tmp --entrypoint /usr/local/bin/entrypoint-gcp -e "INSTANCE_PREFIX=${INSTANCE_PREFIX}" $args "${OPENSHIFT_ANSIBLE_IMAGE:-openshift/origin-ansible:latest}" /bin/bash >/dev/null
else
  docker create --name "$ctr" -v /var/tmp --entrypoint /usr/local/bin/entrypoint-gcp -e "INSTANCE_PREFIX=${INSTANCE_PREFIX}" $args "${OPENSHIFT_ANSIBLE_IMAGE:-openshift/origin-ansible:latest}" "$@" >/dev/null
fi

"${tar_cmd}" ${tar_opts} -c . | docker cp - $ctr:/usr/share/ansible/openshift-ansible/inventory/dynamic/injected

if [[ $# -eq 0 ]]; then
  docker start -ai "${ctr}"
else
  docker start -a "${ctr}"
fi
docker cp "$ctr":/tmp/admin.kubeconfig admin.kubeconfig &>/dev/null || true
