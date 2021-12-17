#!/bin/bash

textfile_dir="${1}"
nodetype="${2}"
cluster="${3}"

output="${textfile_dir}/beegfs_serverstats_${nodetype}_${cluster}"

timeout=59

# run beegfs-ctl
#
# there is a documented limit of 60 seconds history, but I find that the first few
#   seconds are likely inaccurate (intermittently 0)
# so we grab the last 58 seconds
function _run_beegfs-ctl
{
  beegfs_ctl="/opt/beegfs/sbin/beegfs-ctl"
  beegfs_cmd="--serverstats"
  beegfs_args="--nodetype=${nodetype} --history=60"
  timeout ${timeout} ${beegfs_ctl} ${beegfs_cmd} ${beegfs_args} | head -62 | tail -58
}

# _print_stat <kind> <name> <value> [description]
function _print_metric
{
  metric_prefix="beegfs_serverstats"
  metric_desc_prefix="beegfs serverstats"
  metric_type="${1}"
  metric_name="${2}"
  metric_value="${3}"
  metric_desc="${4:-${metric_desc_prefix}}"
  echo "# HELP ${metric_prefix}_${metric_name} ${metric_desc}
# TYPE ${metric_prefix}_${metric_name} ${metric_type}
${metric_prefix}_${metric_name}{beegfs_cluster=\"${cluster}\",nodetype=\"${nodetype}\"} ${metric_value}"

}

stats=$(_run_beegfs-ctl)
echo "" > "${output}.tmp"

# _get_storage_metrics <beegfs-ctl output>
function _get_storage_metrics
{
  # storage has: time_index write_KiB  read_KiB   reqs   qlen bsy
  val=$(echo "${stats}" | awk '{ sum += $2 } END { printf("%0.0f\n",(sum/58) * 1024) }')
  desc="write bytes/sec average over last 58 seconds from beegfs-ctl"
  _print_metric "gauge" "avg_write_bytes_sec" "${val}" "${desc}" >> "${output}.tmp"

  val=$(echo "${stats}" | awk '{ sum += $3 } END { printf("%0.0f\n",(sum/58) * 1024) }')
  desc="read bytes/sec average over last 58 seconds from beegfs-ctl"
  _print_metric "gauge" "avg_read_bytes_sec" "${val}" "${desc}" >> "${output}.tmp"

  val=$(echo "${stats}" | awk '{ sum += $4 } END { printf("%0.0f\n", sum/58) }')
  desc="requests/sec average over last 58 seconds from beegfs-ctl"
  _print_metric "gauge" "avg_requests_sec" "${val}" "${desc}" >> "${output}.tmp"

  val=$(echo "${stats}" | awk '{ sum += $5 } END { printf("%0.0f\n", sum/58) }')
  desc="pending request queue length average over last 58 seconds from beegfs-ctl"
  _print_metric "gauge" "avg_pending_request_queue_length" "${val}" "${desc}" >> "${output}.tmp"

  val=$(echo "${stats}" | awk '{ sum += $6 } END { printf("%0.0f\n", sum/58) }')
  desc="busy threads average over last 58 seconds from beegfs-ctl"
  _print_metric "gauge" "avg_busy_threads" "${val}" "${desc}" >> "${output}.tmp"
} 

# _get_metrics <beegfs-ctl output>
function _get_metrics
{
  val=$(echo "${stats}" | awk '{ sum += $2 } END { printf("%0.0f\n", sum/58) }')
  desc="requests/sec average over last 58 seconds from beegfs-ctl"
  _print_metric "gauge" "avg_requests_sec" "${val}" "${desc}" >> "${output}.tmp"

  val=$(echo "${stats}" | awk '{ sum += $3 } END { printf("%0.0f\n", sum/58) }')
  desc="pending request queue length average over last 58 seconds from beegfs-ctl"
  _print_metric "gauge" "avg_pending_request_queue_length" "${val}" "${desc}" >> "${output}.tmp"

  val=$(echo "${stats}" | awk '{ sum += $4 } END { printf("%0.0f\n", sum/58) }')
  desc="busy threads average over last 58 seconds from beegfs-ctl"
  _print_metric "gauge" "avg_busy_threads" "${val}" "${desc}" >> "${output}.tmp"
}

if [ "${nodetype}" == "storage" ]
then
  _get_storage_metrics
else
  _get_metrics
fi

mv "${output}.tmp" "${output}.prom"
