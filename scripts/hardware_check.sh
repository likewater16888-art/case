#!/usr/bin/env bash
# 常用硬件排查一键检查脚本
# 用法：
#   ./scripts/hardware_check.sh              # 执行全部检查
#   ./scripts/hardware_check.sh gpu          # 只检查显卡
#   ./scripts/hardware_check.sh capture      # 只检查采集卡/视频节点
#   ./scripts/hardware_check.sh serial       # 只检查 USB 转串口和 RS-232
#   ./scripts/hardware_check.sh logs         # 只查看最近硬件相关日志

set -u

section() {
  printf '\n========== %s ==========' "$1"
  printf '\n'
}

run_shell() {
  local description="$1"
  local command="$2"

  printf '\n--- %s ---\n' "$description"
  printf '$ %s\n' "$command"
  bash -lc "$command" 2>&1 || true
}

check_gpu() {
  section "显卡检查"
  run_shell "查看显卡型号" "lspci | egrep -i 'vga|3d|display'"
  run_shell "查看显卡驱动" "lspci -k | grep -A 3 -Ei 'vga|3d|display'"

  if command -v nvidia-smi >/dev/null 2>&1; then
    run_shell "查看 NVIDIA 显卡状态" "nvidia-smi"
  else
    printf '\n--- 查看 NVIDIA 显卡状态 ---\n'
    printf '未找到 nvidia-smi，可能不是 NVIDIA 显卡或未安装 NVIDIA 驱动。\n'
  fi

  run_shell "查看图形/显示相关内核日志" "dmesg | grep -Ei 'nvidia|amdgpu|i915|drm|gpu' | tail -n 80"
}

check_capture() {
  section "采集卡/视频节点检查"
  run_shell "查看 PCIe 采集卡设备" "lspci | grep -Ei 'video|multimedia|capture|blackmagic|magewell|avermedia'"
  run_shell "查看 USB 采集卡设备" "lsusb"
  run_shell "查看 PCIe 采集卡驱动" "lspci -k | grep -A 4 -Ei 'video|multimedia|capture'"
  run_shell "查看视频节点" "ls -l /dev/video* 2>/dev/null"

  if command -v v4l2-ctl >/dev/null 2>&1; then
    run_shell "查看视频设备和节点对应关系" "v4l2-ctl --list-devices"
    run_shell "查看 /dev/video0 支持的格式" "test -e /dev/video0 && v4l2-ctl -d /dev/video0 --list-formats-ext || echo '未发现 /dev/video0'"
  else
    printf '\n--- 查看视频设备详情 ---\n'
    printf '未找到 v4l2-ctl，可安装 v4l-utils 后再查看详细格式。\n'
  fi
}

check_serial() {
  section "USB 转串口 / RS-232 检查"
  run_shell "查看 USB 设备" "lsusb"
  run_shell "查看 USB 转串口生成节点日志" "dmesg | grep -Ei 'ttyUSB|ttyACM|ch34|cp210|ftdi|pl2303' | tail -n 80"
  run_shell "查看当前 USB 串口节点" "ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null"
  run_shell "查看 USB 串口驱动模块" "lsmod | grep -Ei 'usbserial|ch341|cp210x|ftdi_sio|pl2303'"
  run_shell "查看 RS-232 原生串口节点" "ls -l /dev/ttyS* 2>/dev/null"

  if command -v setserial >/dev/null 2>&1; then
    run_shell "查看 RS-232 串口硬件信息" "setserial -g /dev/ttyS* 2>/dev/null"
  else
    printf '\n--- 查看 RS-232 串口硬件信息 ---\n'
    printf '未找到 setserial，如需查看 I/O 地址和中断号可先安装 setserial。\n'
  fi

  run_shell "查看串口参数示例" "test -e /dev/ttyUSB0 && stty -F /dev/ttyUSB0 -a || test -e /dev/ttyS0 && stty -F /dev/ttyS0 -a || echo '未发现 /dev/ttyUSB0 或 /dev/ttyS0'"
}

check_logs() {
  section "日志和权限检查"
  run_shell "查看最近内核日志" "dmesg | tail -n 100"
  run_shell "查看设备权限" "ls -l /dev/video* /dev/ttyUSB* /dev/ttyACM* /dev/ttyS* 2>/dev/null"
  run_shell "查看当前用户所属用户组" "groups"
}

print_help() {
  cat <<'HELP'
常用硬件排查一键检查脚本

用法：
  ./scripts/hardware_check.sh [all|gpu|capture|serial|logs|help]

参数：
  all      执行全部检查（默认）
  gpu      检查显卡型号、驱动、NVIDIA 状态和相关日志
  capture  检查采集卡、视频节点和 V4L2 格式
  serial   检查 USB 转串口、RS-232 串口和串口参数
  logs     检查最近内核日志、设备权限和用户组
  help     显示帮助
HELP
}

main() {
  local target="${1:-all}"

  case "$target" in
    all)
      check_gpu
      check_capture
      check_serial
      check_logs
      ;;
    gpu) check_gpu ;;
    capture) check_capture ;;
    serial) check_serial ;;
    logs) check_logs ;;
    help|-h|--help) print_help ;;
    *)
      printf '未知参数：%s\n\n' "$target" >&2
      print_help
      exit 2
      ;;
  esac
}

main "$@"
