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
# PID="/var/run/admin-authz.pid"
DOCKER="/etc/docker/daemon.json"
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
-> admin-authz -t|--toggle
        - Enable/disable the plugin
-> admin-authz -e|--edit (--set-editor <progname>) plugin|docker
EOF
    exit 0
}

tog(){
    
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

edit(){
    aopt(){
        cat<<EOF
Available options -
config : admin-authz.json file
docker : docker config (add-on)
settings :
    admin-authz -e|--editor --set-editor "editor binary"
EOF
    exit -1
    }
    local x ed=$(jq -r '.handler.editor' $CONFIG)
    if [[ $ed == "null" ]]; then
        for x in vim nano emacs; do
            command -v $x &>/dev/null && {
                ed=$x
                break
            }
        done
    fi
    case $1 in
        "config")   $ed $CONFIG || error "error opening file" ;;
        "plugin")   $ed $PLUGIN || error "error opening file" ;;
        "docker")   $ed $DOCKER || error "error opening file" ;;
        "--set-editor") command -v $2 &>/dev/null || error "Binary \"$2\" not found"
                        x=`mktemp`
                        jq ".handler.editor=\"$2\"" $CONFIG > $x && mv $x $CONFIG || error "Couldn't set editor to $2" $? ;;
               *)   aopt ;;
    esac
}

main(){
    egrep -q ".+(-h|--help)( *$| +)" <<< " $* " && help
    case $1 in
        "-r"|"--reload")    msg BLUE "Reloading daemons"
                            daemon_reload || error "daemon reload experienced errors" ;;
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
        "-e"|"--edit")  edit $2 ;;
        *)  help ;;
    esac
}

getport
main "$@"
