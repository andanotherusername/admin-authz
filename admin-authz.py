from flask import Flask, jsonify, request
import base64, json
from re import search, match
import sys, os
import signal

config="/etc/admin-authz/authz.conf"
enabled=True
plug=Flask(__name__)

def handler(signum, sig):
    global enabled
    if enabled:
        enabled=False
    else:
        enabled=True

signal.signal(signal.SIGUSR1, handler)

def setup(config):
    try:
        with open(config, 'r') as f:
            for x in f.readlines():
                if search(r'^$|^ +$', x)!=None:
                    continue
                return x.split('=')[1]
    except Exception as e:
        print("error: "+str(e))
        ## don't need to kill the service
    return None

def debug(c):
    if len(sys.argv)>1:
        if sys.argv[1]=="-d":
            print(c)

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

def main():
    port=setup(config)
    try:
        with open("/var/run/admin-authz.pid", 'w') as f:
            f.write(str(os.getpid()))
    except Exception as e:
        print("Error occurred while writing pid file\nYou may not be able to disable the plugin")
        print(e)
    try:
        plug.run(port=int(port if port != None else "5000"))
    except Exception as e:
        print("Error occcurred " + str(e))
        print("port num: " + port)

if __name__=="__main__":
    main()
