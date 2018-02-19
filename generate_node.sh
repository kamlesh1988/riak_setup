#!/bin/sh
# Generate a Riak node somewhere on your filesystem *not* where you installed Riak's distribution
# ./generate-node.sh -p 8087 -P 192.168.1.201 -h 8098 -H 192.168.1.201 -d 8099 -D 192.168.1.201 -s riak_kv_eleveldb_backend /mnt/riak/bin/riak /data/solid/riak

while [ "${1:0:1}" = "-" -a "${#1}" -eq 2 ]; do
 case ${1:1:1} in
       p)
     shift
     pb_port="$1"
     shift
     ;;
       P)
     shift
     pb_ip="$1"
     shift
     ;;
       h)
     shift
     http_port="$1"
     shift
     ;;
       H)
     shift
     http_ip="$1"
     shift
     ;;
       d)
     shift
     handoff_port="$1"
     shift
     ;;
       D)
     shift
     handoff_ip="$1"
     shift
     ;;
       s)
     shift
     kv_backend="$1"
     shift
     ;;
       *)
     echo "Unknown option $1"
     exit
 esac
done

if [ ! $# == 2 ]; then
    echo "Usage: $( basename $0 ) /path/to/bin/riak dest_dir"
    exit
fi

src_riak_script="$1"
src_riak_root="$( cd -P "$( dirname "$1" )" && pwd )"
src_riak_admin_script="$src_riak_root/riak-admin"
src_riak_search_cmd="$src_riak_root/search-cmd"

dest_dir="$( dirname "$2/foo" )"
mkdir -p "$dest_dir"
dest_dir="$( cd -P $dest_dir && pwd)"

bin_dir="$dest_dir/bin"
etc_dir="$dest_dir/etc"
log_dir="$dest_dir/log"
pipe_dir="$dest_dir/tmp/pipe/"
data_dir="$dest_dir/data"
lib_dir="$dest_dir/lib"
riak_script="$bin_dir/riak"
riak_admin_script="$bin_dir/riak-admin"
riak_search_cmd="$bin_dir/search-cmd"
vm_args="$etc_dir/vm.args"

app_config="$etc_dir/app.config"
http_port=${http_port:-$((9000 + $(($RANDOM % 100))))}
http_ip=${http_ip:-127.0.0.1}
pb_port=${pb_port:-$((9100 + $(($RANDOM % 100))))}
pb_ip=${pb_ip:-127.0.0.1}
handoff_port=${handoff_port:-$((9200 + $(($RANDOM % 100))))}
handoff_ip=${handoff_ip:-127.0.0.1}
ring_creation_size=${ring_creation_size:-64}
kv_backend=${kv_backend:-riak_kv_bitcask_backend}
node_name="$( basename $dest_dir )@$handoff_ip"


mkdir -p "$bin_dir"
mkdir -p "$etc_dir"
mkdir -p "$log_dir"
mkdir -p "$data_dir"
mkdir -p "$pipe_dir"
mkdir -p "$lib_dir"

cp "$src_riak_script" "$riak_script"
cp "$src_riak_admin_script" "$riak_admin_script"
cp "$src_riak_search_cmd" "$riak_search_cmd"

# Update riak and riak-admin
for script in $riak_script $riak_admin_script $riak_search_cmd; do
    sed -i -e "s/^\(RUNNER_SCRIPT_DIR=\)\(.*\)/\1$(echo $bin_dir|sed -e 's/[\/&]/\\&/g')/" $script
    sed -i -e "s/^\(RUNNER_ETC_DIR=\)\(.*\)/\1$(echo $etc_dir|sed -e 's/[\/&]/\\&/g')/" $script
    sed -i -e "s/^\(RUNNER_USER=\)\(.*\)/\1/" $script
    sed -i -e "s/^\(RUNNER_LOG_DIR=\)\(.*\)/\1$(echo $log_dir|sed -e 's/[\/&]/\\&/g')/" $script
    sed -i -e "s/^\(PIPE_DIR=\)\(.*\)/\1$(echo $pipe_dir|sed -e 's/[\/&]/\\&/g')/" $script
    sed -i -e "s/^\(PLATFORM_DATA_DIR=\)\(.*\)/\1$(echo $data_dir|sed -e 's/[\/&]/\\&/g')/" $script
    sed -i -e 's/\(grep "$RUNNER_BASE_DIR\/.*\/\[b\]eam"\)/grep "$RUNNER_ETC_DIR\/app.config"/' $script
    sed -i -e "s/^\(RUNNER_BASE_DIR=\)\(\${RUNNER_SCRIPT_DIR%\/\*}\)/\1$(echo ${src_riak_root%/*}|sed -e 's/[\/&]/\\&/g')/" $script
    sed -i -e "s/^\(cd \$RUNNER_BASE_DIR\)/cd $(echo $dest_dir|sed -e 's/[\/&]/\\&/g')/" $script
done

# Add this into bin/riak
# ulimit -n 65536
# export LD_PRELOAD_64=libumem.so
# export UMEM_OPTIONS=allocator=best

# Write vm.args
echo "
-name $node_name
-setcookie riak
+K true
+A 64
+W w
+zdbbl 16384
-env ERL_MAX_PORTS 4096
-env ERL_FULLSWEEP_AFTER 0
-env ERL_CRASH_DUMP $log_dir/erl_crash.dump
-env ERL_MAX_ETS_TABLES 8192
" > $vm_args

# Write app.config
echo "
[
 {riak_api, [
 {pb_backlog, 256},
 {pb_ip, \"$pb_ip\"},
 {pb_port, $pb_port}
]},
{riak_core, [
 {ring_state_dir, \"$data_dir/ring\"},
 {http, [ {\"$http_ip\", $http_port } ]},
 {handoff_ip, \"$handoff_ip\"},
 {handoff_port, $handoff_port},
 {platform_bin_dir, \"$bin_dir\"},
 {platform_data_dir, \"$data_dir\"},
 {platform_etc_dir, \"$etc_dir\"},
 {platform_lib_dir, \"$lib_dir\"},
 {platform_log_dir, \"$log_dir\"},
 {dtrace_support, true}
]},
{riak_kv, [
 {storage_backend, $kv_backend},
 {ring_creation_size, $ring_creation_size},
 {mapred_name, "mapred"},
 {mapred_2i_pipe, true},
 {mapred_queue_dir, \"$data_dir/mr_queue\" },
 {map_js_vm_count, 8},
 {reduce_js_vm_count, 6},
 {hook_js_vm_count, 2},
 {http_url_encoding, on},
 {vnode_vclocks, true},
 {legacy_keylisting, true}
]},
{riak_search, [
 {enabled, false}
]},
{merge_index, [
 {data_root, \"$data_dir/merge_index\"},
 {buffer_rollover_size, 1048576},
 {max_compact_segments, 20}
]},
{bitcask, [
 {data_root, \"$data_dir/bitcask\"}
]},
{eleveldb, [
 {data_root, \"$data_dir/leveldb\"}
]},
{wterl, [
 {data_root, \"$data_dir/wt\"}
]},
{hanoi, [
 {data_root, \"$data_dir/hanoi\"},
 {sync_strategy, \"none\"}, % none or {seconds, N}
 {merge_strategy, fast}, % or predictable
 {compression, \"snappy\"} % snappy, gzip or none
]},
{lager, [
 {handlers, [
  {lager_console_backend, info},
  {lager_file_backend, [
   {\"$log_dir/error.log\", error, 10485760, \"$D0\", 5},
   {\"$log_dir/console.log\", info, 10485760, \"$D0\", 5}
  ]}
 ]},
 {crash_log, \"$data_dir/log/crash.log\"},
 {crash_log_msg_size, 65536},
 {crash_log_size, 10485760},
 {crash_log_date, \"\$D0\"},
 {crash_log_count, 5},
 {error_logger_redirect, true}
]},
{riak_sysmon, [
 {process_limit, 30},
 {port_limit, 2},
 {gc_ms_limit, 0},
 {heap_word_limit, 40111000},
 {busy_port, true},
 {busy_dist_port, true}
]},
{sasl, [
 {sasl_error_logger, false}
]}
].
" > $app_config
