#!/bin/bash

textfile_dir="/var/lib/node_exporter/textfile_collector"

/root/beegfs-clientstats-node_exporter.sh thorium meta "${textfile_dir}"
/root/beegfs-clientstats-node_exporter.sh thorium storage "${textfile_dir}"
/root/beegfs-userstats-node_exporter.sh thorium meta "${textfile_dir}"
/root/beegfs-userstats-node_exporter.sh thorium storage "${textfile_dir}"
