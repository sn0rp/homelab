#!/usr/bin/env bash
# smartmon.sh - emit SMART metrics in Prometheus textfile format.
# Based on the node_exporter community smartmon collector, trimmed for the
# homelab. Outputs to stdout; the systemd service redirects to a .prom file.
#
# Emits, per device:
#   smartmon_device_active{disk,type}                 1 if smartctl ran ok
#   smartmon_device_smart_healthy{disk,type}          1 PASSED / 0 FAILED
#   smartmon_device_temperature_celsius{disk,type}    drive temperature
#   smartmon_attr_value{disk,name,...}                raw SMART attribute values
#   smartmon_nvme_percentage_used{disk}               NVMe wear indicator
#   smartmon_nvme_available_spare{disk}               NVMe spare blocks %
set -u

SMARTCTL=/usr/sbin/smartctl
[ -x "$SMARTCTL" ] || SMARTCTL=$(command -v smartctl) || { echo "# smartctl not found"; exit 0; }

echo "# HELP smartmon_device_active Whether smartctl successfully queried the device."
echo "# TYPE smartmon_device_active gauge"
echo "# HELP smartmon_device_smart_healthy SMART overall-health self-assessment (1=PASSED,0=FAILED)."
echo "# TYPE smartmon_device_smart_healthy gauge"
echo "# HELP smartmon_device_temperature_celsius Drive temperature in Celsius."
echo "# TYPE smartmon_device_temperature_celsius gauge"
echo "# HELP smartmon_nvme_percentage_used NVMe percentage used endurance indicator."
echo "# TYPE smartmon_nvme_percentage_used gauge"
echo "# HELP smartmon_nvme_available_spare NVMe available spare percent."
echo "# TYPE smartmon_nvme_available_spare gauge"
echo "# HELP smartmon_attr_value SMART attribute raw value."
echo "# TYPE smartmon_attr_value gauge"

# Enumerate devices smartctl knows about.
device_list=$("$SMARTCTL" --scan-open 2>/dev/null | awk '{print $1 "|" $3}')

for entry in $device_list; do
  dev="${entry%%|*}"
  typ="${entry##*|}"
  [ -n "$dev" ] || continue
  [ -n "$typ" ] || typ="auto"
  label="disk=\"${dev}\",type=\"${typ}\""

  info=$("$SMARTCTL" -i -H -A -d "$typ" "$dev" 2>/dev/null)
  if [ -z "$info" ]; then
    echo "smartmon_device_active{${label}} 0"
    continue
  fi
  echo "smartmon_device_active{${label}} 1"

  # Overall health
  if echo "$info" | grep -qiE 'SMART overall-health.*PASSED|SMART Health Status:.*OK'; then
    echo "smartmon_device_smart_healthy{${label}} 1"
  elif echo "$info" | grep -qiE 'SMART overall-health.*FAILED|SMART Health Status:.*(FAIL|FAILED)'; then
    echo "smartmon_device_smart_healthy{${label}} 0"
  fi

  # Temperature (ATA attribute 194 or NVMe "Temperature:")
  temp=$(echo "$info" | awk '/^194 / {print $10; exit}')
  [ -z "$temp" ] && temp=$(echo "$info" | awk -F: '/Temperature:/ {gsub(/[^0-9]/,"",$2); print $2; exit}')
  if [ -n "$temp" ]; then
    echo "smartmon_device_temperature_celsius{${label}} ${temp}"
  fi

  # NVMe wear indicators
  pu=$(echo "$info" | awk -F: '/Percentage Used:/ {gsub(/[^0-9]/,"",$2); print $2; exit}')
  [ -n "$pu" ] && echo "smartmon_nvme_percentage_used{disk=\"${dev}\"} ${pu}"
  sp=$(echo "$info" | awk -F: '/Available Spare:/ && !/Threshold/ {gsub(/[^0-9]/,"",$2); print $2; exit}')
  [ -n "$sp" ] && echo "smartmon_nvme_available_spare{disk=\"${dev}\"} ${sp}"

  # Key ATA attributes (reallocated, pending, uncorrectable) as raw values.
  echo "$info" | awk -v lbl="$label" '
    /^  *5 / {print "smartmon_attr_value{" lbl ",name=\"reallocated_sector_ct\"} " $10}
    /^197 / {print "smartmon_attr_value{" lbl ",name=\"current_pending_sector\"} " $10}
    /^198 / {print "smartmon_attr_value{" lbl ",name=\"offline_uncorrectable\"} " $10}
  '
done
