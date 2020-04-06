#!/usr/bin/env bash

admin-authz(){
    ## DD
    config="/etc/admin-authz/authz.conf"
    spec="/etc/docker/plugins/admin-authz.spec"

    usage(){
        echo -e "Usage: admin-authz -t/--toggle\n       admin-authz -s/--set-port <port number>" >&2
    }

    daemon(){
        local systemd
        while test -n "$1"; do
            case $1 in
                "-a")   shift && action=$1 && shift ;;
                "-s")   shift && service=$1 && shift ;;
                "--systemd")    systemd=1 && shift ;;
            esac
        done
        if (( $systemd )); then
            sudo systemctl $action $service
            return $?
        fi
        if (( $DD )); then
            sudo service $service $action
            return $?
        else
            sudo systemctl $action $service
            return $?
        fi
        return 0
    }

    set-port(){
        if ! egrep -q '[0-9]+' <<< "$1" || [[ $1 -le 1024 ]] || [[ $1 -gt 65535 ]]; then
            echo "Port number must be an integer, in the range of 1024-65535" >&2
            return 1
        fi

        if echo " $(sudo ss -tulpn | awk '/LISTEN/ {print $5}' | sed -E 's/(.+):([0-9]+$)/\2/g') " | egrep -q " $1 "; then
            echo -e "Can't use this port\nChoose another port" >&2
            return 1
        fi
        echo "setting port"
        echo "port=$1" | sudo tee $config || return 1
        echo "updating plugin details"
        echo "tcp://localhost:$1" | sudo tee $spec || return 1
        echo "restarting admin-authz daemon"
        daemon -s admin-authz -a restart --systemd || return $?
        echo "restarting docker daemon"
        daemon -s docker -a restart || return $?
        return 0
    }
    
    tog(){
        if test ! -f /var/run/admin-authz.pid; then
            echo "pid can't be detected"1>&2
            return -1
        fi
        sudo kill -SIGUSR1 $(cat /var/run/admin-authz.pid) &>/dev/null
        return $?
    }

    (( $# )) || {
        usage
        return 1
    }
    
    case $1 in
        "-s"|"--set-port")  [[ -z $3 ]] && {
                                set-port $2 || {
                                    ret=$?
                                    echo "errors occured while setting port and restarting daemons" 1>&2
                                    return $ret
                                }
                            } || usage ;;
          "-t"|"--toggle")  [[ -z $2 ]] && {
                                tog || {
                                    ret=$?
                                    echo "error toggling admin-authz plugin state" 1>&2
                                    return $ret
                                }
                            } || usage ;;
                        *)  usage ;;
    esac
    return 0
}

admin-authz "$@"
