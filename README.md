# LSLiDAR N10 on Jetson Xavier NX

N10 is a 2D serial LiDAR. It needs **5 V power** and a serial connection at
**230400 baud, 8N1**. The simplest and safest connection to a Jetson is through
a 3.3 V USB-UART adapter.

## 1. Wiring

| N10 | Connect to |
| --- | --- |
| `5V` | regulated 5 V supply |
| `GND` | supply GND and USB-UART GND |
| `TX` | USB-UART `RX` |
| `RX` | USB-UART `TX` (if present/required) |

Do not feed 5 V logic into a Jetson UART pin. Confirm the wire colors and logic
level against the manual supplied with your particular N10 cable. A separate
5 V supply is preferable; join its GND to the adapter GND.

After connecting it, run:

```bash
./scripts/diagnose_n10.sh
```

The result must contain a device such as `/dev/ttyUSB0` or `/dev/ttyACM0` and a
growing RX byte counter.

## 2. Choose the ROS version

Check the Jetson image:

```bash
cat /etc/nv_tegra_release
lsb_release -ds
echo "ROS_DISTRO=${ROS_DISTRO:-not-set}"
```

- JetPack 4 / Ubuntu 18.04 normally uses ROS 1 Melodic.
- JetPack 5 / Ubuntu 20.04 normally uses ROS 2 Foxy or ROS 1 Noetic.
- Do not install a second ROS distribution just for the LiDAR. Use the one the
  robot software already uses.

The current official driver supports N10. For ROS 2 it supports Dashing through
Rolling; for an older JetPack 4 installation, ROS 1 Melodic is usually simpler.

## 3A. ROS 1 (Melodic or Noetic)

ROS must already be installed and `ROS_DISTRO` must be set.

```bash
sudo apt update
sudo apt install -y git build-essential python3-rosdep \
  ros-$ROS_DISTRO-pcl-ros ros-$ROS_DISTRO-rviz

mkdir -p ~/lslidar_ws/src
cd ~/lslidar_ws/src
git clone -b LS-S1_V1.0 https://github.com/Lslidar/Lslidar_ROS1_driver.git
cd ~/lslidar_ws
rosdep install --from-paths src --ignore-src -r -y
catkin_make -DCMAKE_BUILD_TYPE=Release
source devel/setup.bash
```

Find the N10 launch/config names included in the checked-out driver:

```bash
find ~/lslidar_ws/src/Lslidar_ROS1_driver -type f \
  \( -iname '*x10*' -o -iname '*n10*' \) -print
```

Set `serial_port` in the matching config to `/dev/lslidar_n10` and set
`lidar_model` (or `lidar_type`, depending on driver revision) to `N10`. Then run
the X10 launch file reported by the driver's README.

## 3B. ROS 2

```bash
sudo apt update
sudo apt install -y git build-essential python3-rosdep libpcl-dev libpcap-dev \
  libyaml-cpp-dev ros-$ROS_DISTRO-pcl-conversions \
  ros-$ROS_DISTRO-builtin-interfaces ros-$ROS_DISTRO-rosidl-default-generators

mkdir -p ~/lslidar_ws/src
cd ~/lslidar_ws/src
git clone -b LS-S1_V1.0 https://github.com/Lslidar/Lslidar_ROS2_driver.git
cd ~/lslidar_ws
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release
source install/setup.bash
```

Edit `lslidar_driver/config/lslidar_x10.yaml` in the cloned repository. The key
settings are:

```yaml
serial_port: "/dev/lslidar_n10"
lidar_model: "N10"
frame_id: "laser_link"
```

Parameter nesting in the shipped YAML must be preserved. Start it with:

```bash
ros2 launch lslidar_driver lslidar_x10_launch.py
```

Verify that scans arrive:

```bash
ros2 topic list
ros2 topic hz /scan
ros2 topic echo /scan --once
rviz2
```

In RViz2 set `Fixed Frame` to `laser_link`, add a `LaserScan` display, and select
the scan topic shown by `ros2 topic list`.

## 4. Permanent serial permissions

First identify the adapter:

```bash
udevadm info -q property -n /dev/ttyUSB0 | grep -E 'ID_VENDOR_ID|ID_MODEL_ID|ID_SERIAL_SHORT'
```

Copy the generated example and replace its vendor/product IDs with the values
from that command:

```bash
sudo cp config/99-lslidar-n10.rules.example /etc/udev/rules.d/99-lslidar-n10.rules
sudoedit /etc/udev/rules.d/99-lslidar-n10.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Unplug and reconnect the adapter. The stable path `/dev/lslidar_n10` should then
exist. Never use `chmod 777 /dev/ttyUSB0`; udev should assign the correct group.

## Troubleshooting

- No `/dev/ttyUSB*`: check the adapter/cable with `dmesg -w`; some adapters need
  a driver or a better USB cable.
- Device exists but RX stays at zero: swap TX/RX, join grounds, check 5 V power,
  and confirm `230400` baud.
- `Permission denied`: run `sudo usermod -aG dialout "$USER"`, then log out and
  back in.
- Garbled or intermittent scans: use a 3.3 V logic adapter, short signal wires,
  and a stable supply. The N10 nominal consumption is about 1 W, but the supply
  must tolerate motor startup current.
- Jetson debug console conflict: prefer USB-UART. Do not use a header UART until
  its console service and pin voltage have been checked for the carrier board.

Sources: [official LSLiDAR ROS 2 driver](https://github.com/Lslidar/Lslidar_ROS2_driver),
[official ROS 1 driver](https://github.com/Lslidar/Lslidar_ROS1_driver), and the
[N10 datasheet](https://www.lslidar.com/wp-content/uploads/2024/09/N10.pdf).
