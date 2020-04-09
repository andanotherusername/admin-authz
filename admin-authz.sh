#!/usr/bin/env bash

(( $UID )) && {
    echo -e "\e[31mRun this command with sudo/root user\e[0m"
    exit -1
}

trap "warn \"Signal ignored. Please wait for the current process to be over. Won't take long.\"" 1 2 5 15
trap "error \"Exiting...\"" 3

END="\e[0m"
RED="\e[31m"
GREEN="\e[32m"
BROWN="\e[33m"
BLUE="\e[34m"
PURPLE="\e[35m"
CYAN="\e[36m"

CONFIG="/etc/admin-authz/authz.json"
PLUGIN="/etc/docker/plugins/admin-authz.spec"
PID="/var/run/admin-authz.pid"
## DD
EXIT=1

error(){
    echo -e "${RED}-->> $1${END}" 1>&2
    (( $EXIT )) && exit ${2:-1}
    EXIT=1
}

msg(){
    echo -e "$(eval echo \$$1)==> $2${END}"
    shift 2
    (( $# )) && msg "$@"
}

warn(){
    echo -e "${RED}=> $1${END}" 1>&2
}

help(){
    cat<<EOF
Use this command to handle admin-authz plugin easily
-----------------------------------------------------
-> admin-authz -r|--reload
        - Reload docker and admin-authz at the same time
-> admin-authz -q|--query state|port
        - Get the current plugin state and port details
-> admin-authz -t|--toggle
        - Enable/disable the plugin
-> admin-authz -s|--set-port <port number>
        - Set the port number the plugin & dockerd will be communicating through
EOF
    exit 0
}

getport(){
    local x
    if test -f $CONFIG; then
        x=$(cat $CONFIG 2>/dev/null | jq '.port')
        (( $? )) && {
            warn "Config read failed. Creating a config is recommended"
            port=6000
            return 0
        }
        [[ $x != "null" ]] && port=$x || port=6000
    fi
    return 0
}

query(){
    case $1 in
        "state")    if (( $(curl -X GET http://localhost:$port/info/state 2>/dev/null) )); then
                        msg GREEN "The plugin is enabled"
                    else
                        msg BLUE "The plugin is disabled" 
                    fi ;;
         "port")    msg GREEN "The plugin is listening on port ${END}$port" ;;
              *)    error "unknown query" -1 ;;
    esac
}

tog(){
    if [[ -f $PID ]]; then
        kill -SIGUSR1 $(cat $PID)
        return $?
    else
        warn "pid can't be detected"
        return -1
    fi
}

daemon(){
    local systemd action service
    while test -n "$1"; do
        case $1 in
            "-a")   action=$2 && shift 2 ;;
            "-s")   service=$2 && shift 2 ;;
            "--systemd")    systemd=1 && shift ;;
        esac
    done

    if (( ! $DD )) || (( $systemd )); then
        systemctl $action $service &>/dev/null
        return $?
    else
        service $service $action &>/dev/null
        return $?
    fi
    return 0
}

daemon_reload(){
    local x xx ret=0
    msg BLUE "restarting docker & admin-authz"
    for x in stop start; do
        for xx in admin-authz docker; do
            [[ $xx == "admin-authz" ]] && opt="--systemd" || opt=""
            daemon -a $x -s $xx $opt || {
                let ret+=$?
                warn "$xx $x failed"
            }
        done
        systemctl daemon-reload
    done
    (( $ret )) || msg GREEN "Daemon reload successfull"
    return $ret
}

setport(){
    if (( $1 > 65535 )) || (( $1 <= 1024 )); then
        error "Selected port number must be between 1024 & 65535"
    fi
    local ret
    if command -v ss &>/dev/null; then
        if [[ " $(ss -tulpn | awk '/LISTEN/ {print $5}' | sed -E 's/(.+):([0-9]+$)/\2/g') " =~ " $1 " ]]; then
            error "Can't use this port. Port in use"
        fi
        (( $? )) && warn "error occured on safety check"
    else
        if command -v netstat &>/dev/null; then
            if [[ " $(netstat -tulpn | awk '/LISTEN/ {print $5}' | sed -E 's/(.+):([0-9]+$)/\2/g') " =~ " $1 " ]]; then
                error "Can't use this port. Port in use"
            fi
            (( $? )) && warn "error occured on safety check"
        else
            egrep -q " +-f +" <<< "$*" && EXIT=0 error "netstat or ss not found. plugin may not work properly" || error "\"netstat\" or \"ss\" not found. Aborting. Set \"-f\" flag to ignore safety check"
        fi
    fi
    if test ! -f $CONFIG; then
        msg BLUE "Creating config"
        echo "{\"port\":$1, \"debug\":false}" | jq > $CONFIG
        let ret+=$?
    else
        msg BLUE "Updating config files"
        sed -Ei "s/( *\"port\": *)[0-9]+(.*)/\1$1\2/" $CONFIG
        let ret+=$?
    fi
    msg BLUE "Updating config files"
    sed -Ei "s~(.+:)[0-9]+ *$~\1$1~" $PLUGIN
    let ret+=$?
    (( $ret )) && warn "Some config file were not updated" || msg GREEN "Config files successfully updated"
    return $ret
}

main(){
    egrep -q ".+(-h|--help)( *$| +)" <<< " $* " && help
    case $1 in
        "-s"|"--set-port")  shift
                            case $1 in
                                "-f")   [[ $2 =~ ^[0-9]+$ ]] || error "The port number must be an integer" -1
                                        if setport -f $2; then
                                            daemon_reload || error "daemon reload failed"
                                        else 
                                            error "port setup failed" 
                                        fi ;;
                                   *)   [[ $1 =~ ^[0-9]+$ ]] || error "The port number must be an integer" -1
                                        case $2 in
                                            "-f")   if setport -f $1; then
                                                        daemon_reload || error "daemon reload failed"
                                                    else
                                                        error "port setup failed" 
                                                    fi ;;
                                              "")   if setport $1; then
                                                        daemon_reload || error "daemon reload failed"
                                                    else
                                                        error "port setup failed" 
                                                    fi ;;
                                        esac ;;
                            esac ;;
        "-r"|"--reload")    msg BLUE "Reloading daemons"
                            daemon_reload || error "daemon reload experienced errors" ;;
        "-q"|"--query") if [[ -n $2 ]]; then query $2; else help; fi ;;
        "-t"|"--toggle")    if [[ -z $2 ]]; then
                                local cs=$(curl -X GET http://localhost:$port/info/state 2>/dev/null)
                                if tog; then
                                    if (( $cs )); then
                                        msg GREEN "Plugin disabled"
                                    else
                                        msg GREEN "Plugin enabled"
                                    fi
                                else
                                    error "state toggle failed"
                                fi
                            else
                                help
                            fi ;;
        *)  help ;;
    esac
}

getport
main "$@"
