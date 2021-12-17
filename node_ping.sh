#!/bin/bash

node_list="thorium-mgmt thorium-meta-11 thorium-meta-21 thorium-store-101 thorium-store-102 thorium-store-103 thorium-store-104 thorium-store-105 thorium-store-106 thorium-store-107 thorium-store-108 thorium-store-201 thorium-store-202 thorium-store-203 thorium-store-204 thorium-store-205 thorium-store-206 thorium-store-207 thorium-store-208"
textfile_dir="/var/lib/node_exporter/textfile_collector"
interval=10
count=6
timeout=60
cluster="thorium"

metric_help="# HELP node_ping Average ping time to dest over 1 min"
metric_type="# TYPE node_ping gauge"

function ping_node {
  node="${1}"
  fn="${textfile_dir}/ping_${node}"
  echo "${metric_help}" > ${fn}.tmp
  echo "${metric_type}" >> ${fn}.tmp
  ping \
    -i ${interval} \
    -c ${count} \
    -q \
    -w ${timeout} \
    ${node} \
  | awk -F/ -v bc="${cluster}" \
    -v nn=${node} \
    '/^rtt/ {print "node_ping{beegfs_cluster=\""bc"\",dest=\""nn"\"} "$5}' \
  >> ${fn}.tmp \
  && mv ${fn}.tmp ${fn}.prom
}

for node in ${node_list}
do
  ping_node ${node} &
done
