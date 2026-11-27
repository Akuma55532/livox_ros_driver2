#!/usr/bin/env bash
# 在 RK3588 上运行 Release 驱动：限定 CPU4–7，运行期间将两个大核簇的频率下限提高到 1.8 GHz。
# 与同目录的 start_mid360s_rk3588.sh 配套使用。普通用户通过 bash 执行本脚本即可。
set -eo pipefail

# sudo 用于写入内核调频接口。把 ROS 域编号显式传过去，其余参数留给 ros2 launch。
if (( EUID != 0 )); then
  exec sudo -- bash "$0" "${ROS_DOMAIN_ID:-0}" "$@"
fi
: "${SUDO_USER:?Please start this script from a regular user shell}"
domain=${1:-0}
if (( $# )); then shift; fi
launcher="$(dirname "$(realpath "$0")")/start_mid360s_rk3588.sh"
test -r "$launcher" || { echo "Cannot read $launcher" >&2; exit 1; }
if ! tr '\0' '\n' </proc/device-tree/compatible | grep -qx 'rockchip,rk3588'; then
  echo "This profile requires a Rockchip RK3588." >&2
  exit 1
fi

# 每个簇分别保存进入脚本时的下限。锁可避免两个提频实例在退出时相互覆盖。
exec 9>/run/lock/livox-mid360s-rk3588.lock
flock -n 9 || { echo "MID360s frequency profile already in use" >&2; exit 1; }
policies=(/sys/devices/system/cpu/cpufreq/policy{4,6})
for i in 0 1; do
  old_min[$i]=$(cat "${policies[$i]}/scaling_min_freq")
  grep -qw 1800000 "${policies[$i]}/scaling_available_frequencies"
done

# 先设置清理动作，再逐簇写入；正常退出、Ctrl+C 或 TERM/HUP 都会恢复原下限。
restore() {
  for i in 0 1; do echo "${old_min[$i]}" >"${policies[$i]}/scaling_min_freq"; done
}
trap restore EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
for i in 0 1; do
  if (( old_min[i] < 1800000 )); then
    echo 1800000 >"${policies[$i]}/scaling_min_freq"
  fi
done

# 切回原用户，复用低功耗脚本加载工作空间、选择 Fast DDS 并绑定 CPU4–7。
runuser -u "$SUDO_USER" -- env ROS_DOMAIN_ID="$domain" bash "$launcher" "$@" 9>&-
