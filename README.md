# beegfs-monitoring
Prometheus node_exporter textfile scripts for BeeGFS monitoring and Grafana dashboards.

## Architecture
These scripts use `beegfs-ctl` to harvest information, massage it in to node_exporter textfile format, and create a textfile for Prometheus to pull.

We run this based on the crontab in this repo. It is very inefficient, but it does work.

## Metrics
The metrics created by each script:


