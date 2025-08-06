#!/bin/bash
set -euo pipefail

# see https://github.com/siderolabs/talos/releases
# renovate: datasource=github-releases depName=siderolabs/talos
talos_version="${talos_version:-1.10.3}"         #For imager/installer
talos_image_tag="${talos_image_tag:-1.10.3}"     #For file name/dockertag
export talos_version
export talos_image_tag

# see https://github.com/siderolabs/extensions/pkgs/container/qemu-guest-agent
# see https://github.com/siderolabs/extensions/tree/main/guest-agents/qemu-guest-agent
talos_qemu_guest_agent_extension_tag="9.2.0@sha256:00359da7b382d4d802841c0d5c9e3e89410574d1edda3ac3f892b73c5cb6b795"

# see https://github.com/siderolabs/extensions/pkgs/container/drbd
# see https://github.com/siderolabs/extensions/tree/main/storage/drbd
# see https://github.com/LINBIT/drbd
talos_drbd_extension_tag="9.2.13-v1.10.3@sha256:8e80d5341fed7ec7d7e284ce37db85681d38ca53a11ec56be1e178efbc883cdb"

# see https://github.com/siderolabs/extensions/pkgs/container/spin
# see https://github.com/siderolabs/extensions/tree/main/container-runtime/spin
talos_spin_extension_tag="v0.18.0@sha256:93045d3e1f13ddccf4e5cebdff35a00521d26c5166a346cfc5056d6ca3954092"

# see https://github.com/siderolabs/extensions/pkgs/container/iscsi-tools/399927735?tag=v0.2.0
talos_iscsi_tools_extension_tag="v0.2.0@sha256:ead7d05a63a7b9e1ce3fd8b4b88ab301ee3d236549972f9bb83583a799a01366"

# see https://github.com/siderolabs/extensions/pkgs/container/util-linux-tools/408557752?tag=sha256-040b3ae1eb8a05fa0d33ecff1b76cd7eb15e35cf82808a9cccb6c6503517fe37.sig
talos_util_linux_tools_extension_tag="2.40.4@sha256:040b3ae1eb8a05fa0d33ecff1b76cd7eb15e35cf82808a9cccb6c6503517fe37"

export CHECKPOINT_DISABLE='1'
export TF_LOG='DEBUG' # TRACE, DEBUG, INFO, WARN or ERROR.
export TF_LOG_PATH='terraform.log'

export TALOSCONFIG=$PWD/talosconfig.yml
export KUBECONFIG=$PWD/kubeconfig.yml

function step {
  echo "### $* ###"
}

function update-talos-extension {
  # see https://github.com/siderolabs/extensions?tab=readme-ov-file#installing-extensions
  local variable_name="$1"
  local image_name="$2"
  local images="$3"
  local image="$(grep -F "$image_name:" <<<"$images")"
  local tag="${image#*:}"
  echo "updating the talos extension to $image..."
  variable_name="$variable_name" tag="$tag" perl -i -pe '
    BEGIN {
      $var = $ENV{variable_name};
      $val = $ENV{tag};
    }
    s/^(\Q$var\E=).*/$1"$val"/;
  ' do
}

function update-talos-extensions {
  step "updating the talos extensions"
  local images="$(crane export "ghcr.io/siderolabs/extensions:v$talos_version" | tar x -O image-digests)"
  update-talos-extension talos_qemu_guest_agent_extension_tag ghcr.io/siderolabs/qemu-guest-agent "$images"
  update-talos-extension talos_drbd_extension_tag ghcr.io/siderolabs/drbd "$images"
  update-talos-extension talos_spin_extension_tag ghcr.io/siderolabs/spin "$images"
  update-talos-extension talos_iscsi_tools_extension_tag ghcr.io/siderolabs/iscsi-tools "$images"
  update-talos-extension talos_util_linux_tools_extension_tag ghcr.io/siderolabs/util-linux-tools "$images"
}

prepare_yaml_common() {
  local platform="$1"
  local kind="$2"
  local profile_file="$3"
  cat > "$profile_file" <<EOF
arch: amd64
platform: $platform
secureboot: false
version: v${talos_version}
customization:
  extraKernelArgs:
    - net.ifnames=0
input:
  kernel:
    path: /usr/install/amd64/vmlinuz
  initramfs:
    path: /usr/install/amd64/initramfs.xz
  baseInstaller:
    imageRef: ghcr.io/siderolabs/installer:v${talos_version}
  systemExtensions:
    - imageRef: ghcr.io/siderolabs/qemu-guest-agent:${talos_qemu_guest_agent_extension_tag}
    - imageRef: ghcr.io/siderolabs/drbd:${talos_drbd_extension_tag}
    - imageRef: ghcr.io/siderolabs/spin:${talos_spin_extension_tag}
    - imageRef: ghcr.io/siderolabs/iscsi-tools:${talos_iscsi_tools_extension_tag}
    - imageRef: ghcr.io/siderolabs/util-linux-tools:${talos_util_linux_tools_extension_tag}
output:
  kind: $kind
EOF

  if [[ "$platform" == "nocloud" && "$kind" == "image" ]]; then
    cat >> "$profile_file" <<EOF
  imageOptions:
    diskSize: $((2*1024*1024*1024))
    diskFormat: raw
EOF
  fi
  cat >> "$profile_file" <<EOF
  outFormat: raw
EOF
}

# build nocloud image
build_talos_nocloud_image() {
  work_dir="tmp/talos-${talos_image_tag}"
  rm -rf "$work_dir"
  mkdir -p "$work_dir"
  local profile_img="$work_dir/talos-nocloud.yml"

  prepare_yaml_common "nocloud" "image" "$profile_img"
  docker run --rm -i \
    -v "$PWD/$work_dir:/out" \
    -v /dev:/dev \
    --privileged \
    ghcr.io/siderolabs/imager:v${talos_version} \
    - < "$profile_img"

  qemu-img convert -O qcow2 "$work_dir/nocloud-amd64.raw" "$work_dir/talos-${talos_image_tag}.qcow2"
  qemu-img info "$work_dir/talos-${talos_image_tag}.qcow2"
  echo "✅ .qcow2 image created: $work_dir/talos-${talos_image_tag}.qcow2"
}

# build nocloud image + installer docker
upgrade-talos-extensions() {
  build_talos_nocloud_image

  work_dir="tmp/talos-${talos_image_tag}"
  docker_tag="sklpongsit/installer-talos-ext:${talos_image_tag}"
  local profile_inst="$work_dir/talos-metal.yml"
  prepare_yaml_common "metal" "installer" "$profile_inst"

  docker run --rm -i \
    -v "$PWD/$work_dir:/out" \
    --privileged \
    ghcr.io/siderolabs/imager:v${talos_version} \
    - < "$profile_inst"
  docker load < "$work_dir/installer-amd64.tar"
  docker tag "ghcr.io/siderolabs/installer:v${talos_version}" "$docker_tag"

  check_docker_login
  docker push "$docker_tag"
  echo "✅ Docker installer image pushed: $docker_tag"
}

check_docker_login() {
  echo "🔑 Checking Docker Hub login..."
  if ! docker info 2>/dev/null | grep -q 'Username:' ; then
    echo "❌ Docker Hub has not logged in or the session has expired"
    echo "➡️  Please run: docker login"
    exit 1
  fi
  echo "✅ Docker login OK"
}

function init() {
  step 'build talos nocloud image'
  build_talos_nocloud_image
  step 'terraform init'
  terraform init -upgrade
}

function plan {
  step 'terraform plan'
  terraform plan
  terraform output -raw talosconfig > talosconfig.yml 2>/dev/null || true
  terraform output -raw kubeconfig > kubeconfig.yml 2>/dev/null || true
}

function apply {
  step 'terraform apply'
  terraform apply
  terraform output -raw talosconfig > talosconfig.yml
  terraform output -raw kubeconfig > kubeconfig.yml
  health
}

function plan-apply {
  plan
  apply
}

function export-config() {
  step 'terraform output talosconfig'
  terraform output -raw talosconfig > talosconfig.yml

  step 'terraform output kubeconfig'
  terraform output -raw kubeconfig > kubeconfig.yml

  health
}

function health {
  step 'talosctl health'
  local controllers="$(terraform output -raw controllers)"
  local workers="$(terraform output -raw workers)"
  local c0="$(echo $controllers | cut -d , -f 1)"
  talosctl -e $c0 -n $c0 \
    health \
    --control-plane-nodes $controllers \
    --worker-nodes $workers
}

function destroy {
  terraform destroy -auto-approve
}

case "${1:-}" in
  upgrade-talos-extensions)
    upgrade-talos-extensions
    ;;
  update-talos-extensions)
    update-talos-extensions
    ;;
  init)
    init
    ;;
  plan)
    plan
    ;;
  apply)
    apply
    ;;
  plan-apply)
    plan-apply
    ;;
  export-config)
    export-config
    ;;
  health)
    health
    ;;
  info)
    info
    ;;
  destroy)
    destroy
    ;;
  *)
    echo $"Usage: $0 {upgrade-talos-extensions|init|plan|apply|plan-apply|export-config|health|info}"
    exit 1
    ;;
esac