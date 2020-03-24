#!/usr/bin/env bash

trap "error \"Installation inturrupted. Things might not work correctly.\"" 1 2 3 5 15

END="\e[0m"
RED="\e[31m"
GREEN="\e[32m"
BROWN="\e[33m"
BLUE="\e[34m"
PURPLE="\e[35m"
CYAN="\e[36m"

tfile=`mktemp`
config="/etc/admin-authz/authz.conf"
plugin="/etc/docker/plugins/admin-authz.spec"
prog="/usr/local/bin/admin-authz.py"
service="/lib/systemd/system/admin-authz.service"
bappend="authz-set-port"

setperms(){
    sudo chown -R root:root $1 && \
    sudo chmod 700 $1
}

error(){
    echo -e "${RED}-->> $*${END}" 1>&2
    exit 1
}

msg(){
    echo -e "$(eval echo \$$1)==> $2${END}"
    shift 2
    (( $# )) && msg "$@"
}

msg BLUE "Updating system"
sudo apt update &>/dev/null || error "Database update failed"
msg BLUE "Installing updates"
sudo apt upgrade -y || error "Update failed"

msg GREEN "System update successful" BLUE "Installing dependencies"

[[ -f requirements.txt ]] && {
    sudo apt install -y  $(cat requirements.txt) || error "Dependency install failed"
} || sudo apt install -y $(wget https://raw.githubusercontent.com/andanotherusername/admin-authz/master/requirements.txt -qO-) || error "Dependency install failed"

msg GREEN "Dependencies satisfied" BLUE "Creating necessary directories"

for i in /etc/{admin-authz,docker/plugins}; do
    mkdir -p $i && setperms $i
done

[[ -d "/usr/local/bin" ]] || mkdir -p /usr/local/bin
msg GREEN "Directory creation succeessful"

for i in ${config##/*/} ${plugin##/*/} ${prog##/*/} ${service##/*/}; do
    [[ -f $i ]] && ifile=$i || {
        msg BLUE "Downloading $i"
        wget https://raw.githubusercontent.com/andanotherusername/admin-authz/master/$i -qO /tmp/$i || error "File download failed"
        ifile="/tmp/$i"
    }
    case ${i##*.} in
        "conf") sudo install -oroot -groot -m700 $ifile  -t ${config%\/*} ;;
        "spec") sudo install -oroot -groot -m700 $ifile -t ${plugin%\/*} ;;
          "py") sudo install -oroot -groot -m700 $ifile -t ${prog%\/*} ;;
     "service") sudo install -oroot -groot -m700 $ifile -t ${service%\/*} ;;
    esac
done

msg GREEN "Installation successful" PURPLE "Post installation jobs"
echo -e "${CYAN} - stopping docker${END}"

sudo service docker stop
ds_cline="$(egrep '^ExecStart=.+' /lib/systemd/system/docker.service)"
if egrep -q ' --authorization-plugin=.+ *' <<< "$ds_cline"; then
    echo "An authorization plugin already installed. Disabling that first"
    _ds_cline="$(sed -E 's/(--authorization-plugin=).+ */\1admin-authz/1; ' <<< $ds_cline)"
    sudo sed -Ei "s|^ExecStart=.+|#&\n$_ds_cline|" /lib/systemd/system/docker.service
else
    sudo sed -Ei 's/^ExecStart=.+/& --authorization-plugin=admin-authz/1' /lib/systemd/system/docker.service
fi
echo -e "${CYAN} - starting docker & admin-authz${END}"
sudo systemctl daemon-reload
sudo systemctl enable --now admin-authz
sudo service docker start

[[ -f $bappend ]] || wget http://raw.githubusercontent.com/andanotherusername/admin-authz/master/$bappend -qO /tmp/$bappend || error "error occured"
cat "/tmp/$bappend" >> $HOME/.bashrc && rm /tmp/$bappend

msg PURPLE "Post install processes are now finished. Restart the virtual terminal ... "

