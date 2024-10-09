#!/bin/sh

GIB_IN_BYTES="1073741824"

target="${1:-pivirt}"
image_path="/sdcard/filesystem.img"
zip_path="/filesystem.zip"

if [ ! -e $image_path ]; then
  echo "No filesystem detected at ${image_path}!"
  if [ -e $zip_path ]; then
      echo "Extracting fresh filesystem..."
      unzip $zip_path
      mv -- *.img $image_path
  else
    exit 1
  fi
fi

qemu-img info $image_path
image_size_in_bytes=$(qemu-img info --output json $image_path | grep "virtual-size" | awk '{print $2}' | sed 's/,//' | tail -n1)
if [[ "$(($image_size_in_bytes % ($GIB_IN_BYTES * 2)))" != "0" ]]; then
  new_size_in_gib=$((($image_size_in_bytes / ($GIB_IN_BYTES * 2) + 1) * 2))
  echo "Rounding image size up to ${new_size_in_gib}GiB so it's a multiple of 2GiB..."
  qemu-img resize $image_path "${new_size_in_gib}G"
fi

if [ "${target}" = "zero2" ]; then
  emulator=qemu-system-aarch64
  machine=raspi3b
  cpu=cortex-a53
  smp=4
  memory=1024m
  kernel_pattern=kernel8.img
  dtb_pattern=bcm2710-rpi-3-b-plus.dtb
  append="dwc_otg.fiq_fsm_enable=0"
  nic="-netdev user,id=net0,hostfwd=tcp::5022-:22 -device usb-net,netdev=net0"
elif [ "${target}" = "pi3" ]; then
  emulator=qemu-system-aarch64
  machine=raspi3b
  cpu=cortex-a53
  smp=4
  memory=1024m
  kernel_pattern=kernel8.img
  dtb_pattern=bcm2710-rpi-3-b-plus.dtb
  append="dwc_otg.fiq_fsm_enable=0"
  nic="-netdev user,id=net0,hostfwd=tcp::5022-:22 -device usb-net,netdev=net0"
elif [ "${target}" = "pivirt" ]; then
  emulator=qemu-system-arm
  machine=virt
  cpu=cortex-a7
  smp="$(nproc)"
  memory=1024m
  dtb_pattern=""
  #dtb="/root/qemu-rpi-kernel/bcm2836-rpi-2-b.dtb"
  dtb=""
  kernel_pattern=""
  kernel="/root/zImage"
  append=""
  root=/dev/vda2
  nic="-netdev user,id=mynet,hostfwd=tcp::5022-:22 -device virtio-net-device,netdev=mynet"
  img_options=",if=none,id=hd0"
  drive_extra="-device virtio-blk-device,drive=hd0,bootindex=0"
else
  echo "Target ${target} not supported"
  echo "Supported targets: pi1 pi2 pi3"
  exit 2
fi

if [ "${kernel_pattern}" ] && [ "${dtb_pattern}" ]; then
  fat_path="/fat.img"
  echo "Extracting partitions"
  fdisk -l ${image_path} \
    | awk "/^[^ ]*1/{print \"dd if=${image_path} of=${fat_path} bs=512 skip=\"\$4\" count=\"\$6}" \
    | sh

  echo "Extracting boot filesystem"
  fat_folder="/fat"
  mkdir -p "${fat_folder}"
  fatcat -x "${fat_folder}" "${fat_path}"

  root=/dev/mmcblk0p2

  echo "Searching for kernel='${kernel_pattern}'"
  kernel=$(find "${fat_folder}" -name "${kernel_pattern}")

  echo "Searching for dtb='${dtb_pattern}'"
  dtb=$(find "${fat_folder}" -name "${dtb_pattern}")
fi

if [ "${kernel}" = "" ] || ([ "${dtb}" = "" ] && [ "${dtb_pattern}" != "" ]); then
  echo "Missing kernel='${kernel}' or (dtb='${dtb}' for dtb_pattern='${dtb_pattern}')"
  exit 2
fi

# Some configurations don't need a dtb file and the flag should be skipped
if [ -n "$dtb" ]; then
    dtb_flag="--dtb ${dtb}"
else
    dtb_flag=""
fi

echo "Booting QEMU machine \"${machine}\" with kernel=${kernel} dtb=${dtb}"
set -x
exec ${emulator} \
  --machine "${machine}" \
  --cpu "${cpu}" \
  --smp "${smp}" \
  --m "${memory}" \
  --drive "format=raw,file=${image_path}${img_options}" ${drive_extra} \
  ${nic} \
  ${dtb_flag} \
  --kernel "${kernel}" \
  --append "rw earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=${root} rootwait panic=1 ${append}" \
  --no-reboot \
  --display none \
  --serial mon:stdio
