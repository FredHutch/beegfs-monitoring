#!/bin/bash

cluster="${1}"
textfile_dir="${2}"

output="${textfile_dir}/beegfs_capacity_${cluster}"

# run beegfs-ctl
function _run_beegfs-ctl
{
  beegfs_ctl="/opt/beegfs/sbin/beegfs-ctl"
  beegfs_cmd="--listtargets"
  beegfs_args="--nodetype=storage --spaceinfo"
  ${beegfs_ctl} ${beegfs_cmd} ${beegfs_args} | tail -16
}

# _print_stat <kind> <name> <value> [description]
function _print_metric
{
  metric_prefix="beegfs_capacity"
  metric_desc_prefix="beegfs capacity info"
  metric_type="${1}"
  metric_name="${2}"
  metric_value="${3}"
  metric_desc="${4:-${metric_desc_prefix}}"
  echo "# HELP ${metric_prefix}_${metric_name} ${metric_desc}
# TYPE ${metric_prefix}_${metric_name} ${metric_type}
${metric_prefix}_${metric_name}{beegfs_cluster=\"${cluster}\"} ${metric_value}"

}

stats=$(_run_beegfs-ctl)
echo "" > "${output}.tmp"

#TargetID        Total         Free    %      ITotal       IFree    %   NodeID

bytes_total=$(echo "${stats}" | awk '{ sum += $2 } END { printf("%d\n",(sum * 1024.0 * 1024.0 * 1024.0)) }')
desc="total capacity of all storage targets"
_print_metric "gauge" "total_bytes" "${bytes_total}" "${desc}" >> "${output}.tmp"

bytes_free=$(echo "${stats}" | awk '{ sum += $3 } END { printf("%d\n",(sum * 1024.0 * 1024.0 * 1024.0)) }')
desc="free capacity of all storage targets"
_print_metric "gauge" "free_bytes" "${bytes_free}" "${desc}" >> "${output}.tmp"

inodes_total=$(echo "${stats}" | awk '{ sum += $5 } END { printf("%d\n",sum) }')
desc="total inodes of all storage targets"
_print_metric "gauge" "total_inodes" "${inodes_total}" "${desc}" >> "${output}.tmp"

inodes_free=$(echo "${stats}" | awk '{ sum += $6 } END { printf("%d\n",sum) }')
desc="free inodes of all storage targets"
_print_metric "gauge" "free_inodes" "${inodes_free}" "${desc}" >> "${output}.tmp"

mv "${output}.tmp" "${output}.prom"
