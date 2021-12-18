# beegfs-monitoring
Prometheus node_exporter textfile scripts for BeeGFS monitoring and Grafana dashboards.

## Architecture
These scripts use `beegfs-ctl` to harvest information, massage it in to node_exporter textfile format, and create a textfile for Prometheus to pull.

We run this based on the crontab in this repo. It is very inefficient, but it does work.

## Assumptions and notes
  * Bytes. Everything in bytes always.
  * The `textfiledir` refers to the path to node_exporter's textfile directory.
  * To avoid Prometheus pulling an incomplete file, output is buffered into /tmp and then copied to textfiledir.
  * The `nodetype` refers to the BeeGFS nodetype (*meta* and *storage* mostly).
  * The `mirrorid` refers to BeeGFS mirror group ID. This was all built with buddy mirroring. I will try to remove all that at some point.

## Metrics
Below are references to the metrics reported by each script. Typically each script produces a single textfile.

### beegfs-capacity.sh

**Parameters:** *clustername* *textfiledir*

**beegfs-ctl command:** `--listtargets --nodetype=storage --spaceinfo`

| metric name | metric type | metric description | labels |
|-------------|-------------|--------------------|--------|
| beegfs_capacity_bytes_total | gauge | total capacity of all storage targets | beegfs_cluster=*clustername* |
| beegfs_capacity_bytes_free | gauge | free capacity of all storage targets | beegfs_cluster=*clustername* |
| beegfs_capacity_inodes_total | gauge | total inodes of all storage targets | beegfs_cluster=*clustername* |
| beegfs_capcity_inodes_free | gauge | free inodes of all storage targets | beegfs_cluster=*clustername* |

### beegfs-clientstats-node_exporter.sh

**Parameters:** *clustername* *nodetype* *textfiledir*

**beegfs-ctl command:** `--clientstats --nodetype = <nodetype> --interval=0 --perinterval`

| metric name | metric type | metric description | labels |
|-------------|-------------|--------------------|--------|
| beegfs_ctl_milliseconds | gauge | duration in ms of beegfs-ctl call | beegfs_cluster=*clustername* nodetype=*nodetype* collector="collector" command="client stats" |
| beegfs_clientstats | gauge | statistics about clients from beegfs-ctl | beegfs_cluster=*clustername* nodetype=*nodetype* client=*client hostname/ip* method=*method* |

**Notes**
  * This was split by nodetype to run in parallel, you could combine them.
  * The script produces a lot of output, depending on how many clients your BeeGFS cluster has.
  * The script looks up hostnames and replaces IPs when there is an answer.
  * The script run beegfs-ctl with --interval 0 --perinterval, which means you'll get counters really and should graph with a rate over time.

### beegfs-resync-node_exporter.sh

**Parameters:** *nodetype* *mirrorid* *clustername* *textfiledir*

**beegfs-ctl command:** `--resyncstats --nodetype=<nodetype> --mirrorgroupid=<mirrorid>`
  
| metric name | metric type | metric description | labels |
|-------------|-------------|--------------------|--------|
| beegfs_resync | gauge | beegfs resync stats | beegfs_cluster=*clustername* nodetype=*nodetype* mirrorgroupid=*mirrorid* [state=*state*] [sync_session_error="1 or 0"] |
  
**Notes**
  * This produces no output if a resync is not running.
  * One output file is created per mirrorgroupid.
  * This is the output of the beegfs-ctl command:
```
# Job state: Running
# Job start time: Tue Aug 13 15:04:25 2019
# # of discovered dirs: 4332441
# # of discovery errors: 0
# # of synced dirs: 4282485
# # of synced files: 149721396
# # of dir sync errors: 0
# # of file sync errors: 0
# # of client sessions to sync: 0
# # of synced client sessions: 0
# session sync error: No
# # of modification objects synced: 0
# # of modification sync errors: 0
  ```
  * Lables are created from the output and formatted when there are values to be reported. Ex: discovered_dirs=4332441
  
### beegfs-server-stats-node_exporter.sh
  
**Parameters:** *textfiledir* *nodetype* *clustername*

**beegfs-ctl command:** `--serverstats --nodetype=<nodetype> --history=60`
  
| metric name | metric type | metric description | labels |
|-------------|-------------|--------------------|--------|
| beegfs_serverstats_avg_requests_sec | gauge | requests/sec average over last 58 seconds from beegfs-ctl | beegfs_cluster=*clustername* nodetype=*nodetype* |
| beegfs_serverstats_avg_pending_request_queue_length | gauge | pending request queue length average over last 58 seconds from beegfs-ctl | beegfs_cluster=*clustername* nodetype=*nodetype* |
| beegfs_serverstats_avg_busy_threads | gauge | busy threads average over last 58 seconds from beegfs-ctl | beegfs_cluster=*clustername* nodetype=*nodetype* |
| beegfs_serverstats_avg_write_bytes_sec | gauge | write bytes/sec average over last 58 seconds from beegfs-ctl | beegfs_cluster=*clustername* nodetype="storage" |
| beegfs_serverstats_avg_read_bytes_sec | gauge | read bytes/sec average over last 58 seconds from beegfs-ctl | beegfs_cluster=*clustername* nodetype="storage" |

**Notes**
  * Produces output per nodetype.
  * Storage nodes produce two additional stats.
  * Looks at the last 58 seconds.

### beegfs-state-node_exporter.sh

**Parameters:** *clustername* *textfiledir*

**beegfs-ctl command:** `--listnodes --nodetype=mgmt --reachable` `--listnodes --nodetype=<nodetype>` ` --listtargets --nodetype=<nodetype>--state --longnodes --spaceinfo --mirrorgroups` `

| metric name | metric type | metric description | labels |
|-------------|-------------|--------------------|--------|
| beegfs_node_reachable | gauge | reachablity of node | beegfs_cluster=*clustername* nodetype=*nodetype* hostname=*hostname* |
| beegfs_node_count | gauge | count of current nodes in cluster | beegfs_cluster=*clustername* nodetype=*nodetype* |
| beegfs_node_mirror_primary | gauge | is node primary? | beegfs_cluster=*clustername* nodetype=*nodetype* hostname=*hostname* |
| beegfs_node_mirror_secondary | gauge | is node secondary? | beegfs_cluster=*clustername* nodetype=*nodetype* hostname=*hostname* |
| beegfs_node_reachable | gauge | reachability of node | beegfs_cluster=*clustername* nodetype=*nodetype* hostname=*hostname* |
| beegfs_node_consistent | gauge | consistency of node | beegfs_cluster=*clustername* nodetype=*nodetype* hostname=*hostname* |
| beegfs_node_space_total_gib | gauge | total space on target in gib | beegfs_cluster=*clustername* nodetype=*nodetype* hostname=*hostname* |
| beegfs_node_space_free_gib | gauge | free space on target in GiB | beegfs_cluster=*clustername* nodetype=*nodetype* hostname=*hostname* |
| beegfs_node_space_free_gib | gauge | free space on target in GiB | beegfs_cluster=*clustername* nodetype=*nodetype* hostname=*hostname* |
| beegfs_node_space_free_pct | gauge | percent of space in GiB free on target | beegfs_cluster=*clustername* nodetype=*nodetype* hostname=*hostname* |
| beegfs_node_space_total_inodes | gauge | total inodes on target in millions (M) | beegfs_cluster=*clustername* nodetype=*nodetype* hostname=*hostname* |
| beegfs_node_space_free_inodes | gauge | total free inodes on target in millions (M) | beegfs_cluster=*clustername* nodetype=*nodetype* hostname=*hostname* |
| beegfs_node_space_free_inodes_pct | gauge | percentage of inodes free on target | beegfs_cluster=*clustername* nodetype=*nodetype* hostname=*hostname* |

**Notes**
  * Produces output files based on node hostnames
  * Consistency and reachability are 0/1 binary values
  * Use conflicts for alerting (like, no node in a type is primary)

### beegfs-userstats-node_exporter.sh

**Parameters:** *clustername* *nodetype* *textfiledir*

**beegfs-ctl command:** `--userstats --nodetype=<nodetype> --interval=0 --perinterval`

| metric name | metric type | metric description | labels |
|-------------|-------------|--------------------|--------|
| beegfs_ctl_milliseconds | gauge | duration in ms of beegfs-ctl call | beegfs_cluster=*clustername* nodetype=*nodetype* collector="collector" command="client stats" |
| beegfs_userstats | gauge | statistics about users from  beegfs-ctl | beegfs_cluster=*clustername* nodetype=*nodetype* user=*username* method=*method* |

**Notes**
  * Much like clientstats above.
  * Username is looked up from UID in output.
