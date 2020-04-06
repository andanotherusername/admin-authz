from flask import Flask, jsonify, request
import base64, json
from re import search, match
import sys, os
from signal import signal, SIGUSR1

config="/etc/admin-authz/authz.json"
enabled=True
plug=Flask(__name__)
port=None
plug.debug=False

try:
    with open(config, 'r') as f:
        for key, value in json.load(f).items():
            if key=="port":
                port=value
            elif key=="debug":
                plug.debug=value
except Exception as e:
    print("error: "+str(e))
    ## don't need to kill the service

@plug.route("/info/<query>", methods=["GET"])
def state(query):
    if query=="state":
        qu=("enabled" if enabled else "not enabled")
        return "The plugin is " + qu
    else:
        return 1/0#"Unknown query\n"


@plug.route("/Plugin.Activate", methods=["POST"])
def start():
    return jsonify({"Implements": ["authz"]})

@plug.route("/AuthZPlugin.AuthZReq", methods=["POST"])
def req():
    res=json.loads(request.data)
    debug(res)
    response={"Allow":True}
    if search(r'/(exec)$', res["RequestUri"]) != None:
        dd=json.loads(base64.b64decode(res["RequestBody"]))
        debug(dd)
        if match(r'^$|(root)|0', dd["User"])!=None:
            response={"Allow":False, "Msg":"You are not authorized to use this command"}
    if not enabled:
        response={"Allow":True}
    return jsonify(**response)


@plug.route("/AuthZPlugin.AuthZRes", methods=["POST"])
def res():
    response={"Allow":True}
    return jsonify(**response)

def handler(signum, sig):
    global enabled
    enabled=(False if enabled else True)

signal(SIGUSR1, handler)

def main():
    global port
    try:
        with open("/var/run/admin-authz.pid", 'w') as f:
            f.write(str(os.getpid()))
    except Exception as e:
        print("Error occurred while writing pid file\nYou may not be able to disable the plugin")
        print(e)
    try:
        plug.run(port=(port if port!=None else 6000))
    except Exception as e:
        print("Error occcurred " + str(e))
        print("port num: " + port)

if __name__=="__main__":
    main()
