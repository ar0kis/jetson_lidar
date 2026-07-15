#!/usr/bin/env bash
set -u

echo "== Platform =="
uname -a
if command -v lsb_release >/dev/null 2>&1; then
  lsb_release -ds
fi
if [[ -r /etc/nv_tegra_release ]]; then
  head -n 1 /etc/nv_tegra_release
fi
echo "ROS_DISTRO=${ROS_DISTRO:-not-set}"

echo
echo "== Serial devices =="
shopt -s nullglob
devices=(/dev/ttyUSB* /dev/ttyACM* /dev/lslidar_n10)
if ((${#devices[@]} == 0)); then
  echo "No USB serial device found. Connect the adapter and inspect: sudo dmesg -w"
  exit 1
fi

for device in "${devices[@]}"; do
  [[ -e "$device" ]] || continue
  ls -l "$device"
  if [[ -r "/sys/class/tty/${device##*/}/device/uevent" ]]; then
    sed -n -e '/^DRIVER=/p' -e '/^PRODUCT=/p' \
      "/sys/class/tty/${device##*/}/device/uevent"
  fi
done

echo
echo "== Permissions =="
id
if id -nG | tr ' ' '\n' | grep -qx dialout; then
  echo "OK: user is in the dialout group"
else
  echo "FIX: sudo usermod -aG dialout $USER, then log out and back in"
fi

echo
echo "== Serial data sample at 230400 8N1 (up to 3 seconds) =="
echo "This consumes at most 64 bytes and must be run while the ROS driver is stopped."
for device in "${devices[@]}"; do
  echo "$device:"
  if [[ ! -r "$device" ]]; then
    echo "  cannot read (fix dialout membership first)"
    continue
  fi
  stty -F "$device" 230400 cs8 -cstopb -parenb raw -echo
  sample=$(timeout 3 dd if="$device" bs=64 count=1 status=none 2>/dev/null | od -An -tx1)
  if [[ -n "$sample" ]]; then
    echo "  RX bytes:$sample"
  else
    echo "  no data: check power, common GND, and TX -> adapter RX"
  fi
done
