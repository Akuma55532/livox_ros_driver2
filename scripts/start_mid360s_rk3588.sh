#!/usr/bin/env bash
# 在香橙派 5 Max 上以普通用户启动 MID360s：使用已编译的 Release 驱动，让内核按负载调频。
# 用法：~/ws_livox/start_mid360s_rk3588.sh，额外参数会传给 ros2 launch。
set -eo pipefail

# 在 RK3588 上，CPU4–7 是四个 Cortex-A76 大核。
if ! tr '\0' '\n' </proc/device-tree/compatible | grep -qx 'rockchip,rk3588'; then
  echo "This profile requires a Rockchip RK3588." >&2
  exit 1
fi

source /opt/ros/humble/setup.bash
source "$HOME/ws_livox/install/setup.bash"
export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp

# launch 和它启动的驱动继承同一 CPU 亲和性；另一个终端里的节点由其自身设置决定。
exec taskset -c 4-7 ros2 launch livox_ros_driver2 msg_MID360s_launch.py "$@"
