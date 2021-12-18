#!/bin/bash

cluster="${1}"
nodetype="${2}"
textfile_dir="${3}"

metric_class="beegfs_userstats"
my_metrics=""

output="${textfile_dir}/${metric_class}_${nodetype}"

timeout=59

tempdir=$(mktemp -d) 
trap "rm -rf ${tempdir}" EXIT

#beegfs_cfgfile="/etc/beegfs/beegfs-client.d/${cluster}.conf"
beegfs_cfgfile="/etc/beegfs/beegfs-client.conf"
beegfs_ctl="/opt/beegfs/sbin/beegfs-ctl"

uid_file="uid2user.json"

# _print_stat <kind> <name> <value> [description]
function _print_metric
{
  metric_prefix="${metric_class}"
  metric_desc_prefix="beegfs userstats"
  metric_type="${1}"
  metric_name="${2}"
  metric_user="${3}"
  metric_value="${4}"
  metric_desc="${5:-${metric_desc_prefix}}"
  echo "${metric_prefix}{beegfs_cluster=\"${cluster}\",nodetype=\"${nodetype}\",user=\"${metric_user}\",method=\"${metric_name}\"} ${metric_value}"
}

function _run_beegfs_ctl
{
  begin=$(date +%s.%3N)
  (timeout ${timeout} ${1})
  end=$(date +%s.%3N)
  secs=$(echo "((${end}-${begin}) * 1000)/1" | bc)
  echo "# HELP beegfs_ctl_milliseconds duration in ms of beegfs-ctl call
# TYPE beegfs_ctl_milliseconds gauge
beegfs_ctl_milliseconds{beegfs_cluster=\"${cluster}\",nodetype=\"${nodetype}\",collector=\"userstats\",command=\"${2}\"} ${secs}">> "${output}.tmp"
}

function _build_beegfs_cmd
{
  beegfs_cmd="${beegfs_ctl} --cfgFile=${beegfs_cfgfile} --userstats --nodetype=${nodetype} --interval=0 --perinterval"
  if [ "${nodetype}" == "meta" ]
  then
    metas=$(${beegfs_ctl} --cfgFile=${beegfs_cfgfile} --listtargets --nodetype=meta --mirrorgroups)
    meta_primary=$(echo "${metas}" | awk '/primary/ {print $4}')
    beegfs_cmd="${beegfs_cmd} ${meta_primary}"
  fi
}

function _client_ip_lookup
{
  ip="${1}"

  case ${ip} in
  140.107.221.186)
    hn="rhino1"
    ;;
  140.107.221.187)
    hn="rhino2"
    ;;
  140.107.221.188)
    hn="rhino3"
    ;;
  *)
    hn=$(getent hosts "${ip}" | awk '{print $2}' | sed 's/.fhcrc.org$//')
    ;;
  esac

  if [ -n "${hn}" ]
  then
    echo "${hn}"
  else
    echo "${ip}"
  fi
}

function _uid_lookup
{
  uid="${1}"
  case ${uid} in
  0)
    username="root"
    ;;
  8)
    username="mail"
    ;;
  33)
    username="www-data"
    ;;
  104)
    username="_apt"
    ;;
  105)
    username="uuidd"
    ;;
  114)
    username="postfix"
    ;;
  65534)
    username="nobody"
    ;;
  *)
    username=$(cat ${uid_file} | grep -E "[\"]${1}[\"]" | awk -F\" '{print $4}')
    ;;
  esac

  user_re="^[a-z0-9-]+$"
  if [[ ${username} =~ ${user_re} ]]
  then
    echo "${username}"
  else
    echo "${1}"
  fi
}

# example outputs
#
# meta cmd: beegfs-ctl --clientstats --nodetype=meta --interval=0 --perinterval
# 23.174.134.23        56624 [sum]  0 [ack]  10 [close]  0 [entInf]  0 [nodeInf]  0 [fndOwn]  0 [mkdir]  0 [create]  488 [rddir]  0 [refrEnt]  0 [mdsInf]  0 [rmdir]  0 [rmLnk]  0 [mvDirIns]  0 [mvFiIns]  11 [open]  2 [ren]  9 [sChDrct]  0 [sAttr]  0 [sDirPat]  30911 [stat]  0 [statfs]  0 [trunc]  0 [symlnk]  2 [unlnk]  0 [lookLI]  7723 [statLI]  17468 [revalLI]  0 [openLI]  0 [createLI]  0 [hardlnk]  0 [flckAp]  0 [flckEn]  0 [flckRg]  0 [dirparent]  0 [listXA]  0 [getXA]  0 [rmXA]  0 [setXA]  0 [mirror]
# storage cmd: beegfs-ctl --clientstats --nodetype=storage --interval=0 --perinterval
# 23.174.134.23        61957 [sum]  0 [ack]  20 [sChDrct]  0 [getFSize]  0 [sAttr]  18048 [statfs]  0 [trunc]  0 [close]  0 [fsync]  22385 [ops-rd]  313.54 [MiB-rd]  21504 [ops-wr]  84 [MiB-wr]  0 [gendbg]  0 [hrtbeat]  0 [remNode]  0 [nodeInf]  0 [storInf]  0 [unlnk]

function _process_user
{
  uid="${1}"
  metrics="${2}"
  username=$(_uid_lookup ${uid})
  label=0
  for val in ${metrics}
  do
    if [ "${label}" == 0 ]
    then
      num="${val}"
      label=1
    else
      # beegfs-ctl --interval 0 --perinterval returns exp notation
      #  and prometheus doesn't accept floats
      if [[ "${num}" =~ [Ee.]+ ]]
      then
        value=$(printf "%0.0f\n" ${num})
      else
	value="${num}"
      fi
      if [[ "${value}" =~ [0-9]+ ]]
      then
        _print_metric "gauge" "${val}" "${username}" "${value}" >> "${tempdir}/${uid}"
      fi
      label=0
    fi
  done
}

function new_parse
{
  while read uid metrics
  do
    _process_user "${uid}" "${metrics}" &
  done < <(_run_beegfs_ctl "${beegfs_cmd}" "userstats" | grep -v Sum: | tr -d '[]')
}

function parse_metrics
{
  #parse_begin=$(date +%s.%3N)
  beegfs_output="${1}"
  while read client_ip metrics
  do
    #cloop_begin=$(date +%s.%3N)
    client=$(_client_ip_lookup ${client_ip})
    #cloop_ip=$(date +%s.%3N)
    #echo -n "cloop_ip: "
    #echo "((${cloop_ip}-${cloop_begin})*1000)/1" | bc
    label=0
    value=""
    for val in ${metrics}
    do
      #mloop_begin=$(date +%s.%3N)
      if [ "${label}" == 0 ]
      then
        num="${val}"
	label=1
	#cloop_value=$(date +%s.%3N)
	#echo -n "mloop value: "
	#echo "((${cloop_value}-${mloop_begin})*1000)/1" | bc
      else
	# beegfs-ctl --interval 0 --perinterval returns exp notation
	#  and prometheus don't accept floats
	if [[ "${num}" =~ [eE]+ ]]
	then
	  value=$(printf "%0.0f\n" ${num})
	else
	  value="${num}"
	fi
        if [[ "${value}" =~ [0-9]+ ]]
	then
          #_print_metric "gauge" "${metric}" "${client}" "${value}" >> "${output}.tmp"
	  _print_metric "gauge" "${metric}" "${client}" "${value}"
	fi
	label=0
	#mloop_end=$(date +%s.%3N)
	#echo -n "mloop print: "
	#echo "((${mloop_end}-${mloop_begin})*1000)/1" | bc
      fi
    done
    #cloop_end=$(date +%s.%3N)
    #echo -n "cloop done: "
    #echo "((${cloop_end}-${cloop_begin})*1000)/1" | bc
  done < <(_run_beegfs_ctl "${beegfs_cmd}" "clientstats" | grep -v Sum: | tr -d '[]' | tr '-' '_')
  #parse_end=$(date +%s.%3N)
  #echo -n "parse done: "
  #echo "((${parse_end}-${parse_begin})*1000)/1" | bc
}

#main_begin=$(date +%s.%3N)
echo -n "" > "${output}.tmp"
_build_beegfs_cmd
new_parse
wait
echo "# HELP beegfs_userstats statistics about users from  beegfs-ctl
# TYPE beegfs_userstats gauge" >> "${output}.tmp"
cat ${tempdir}/* >> "${output}.tmp"
#beegfs_output=$(_run_beegfs_ctl "${beegfs_cmd}" "clientstats")
#parse_metrics "${beegfs_output}"
#parse_metrics
#echo "${my_metrics}" >> "${output}.tmp"
mv "${output}.tmp" "${output}.prom"
#main_end=$(date +%s.%3N)
#echo -n "main done: "
#echo "((${main_end}-${main_begin})*1000)/1" | bc
