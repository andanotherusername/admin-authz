from flask import Flask, jsonify, request
import base64, json
from re import search
import sys, os

config="/etc/admin-authz/authz.conf"

plug=Flask(__name__)

def setup(config):
    if os.path.isfile(config):
        def _setup():
            try:
                with open(config, 'r') as f:
                    for x in f.readlines():
                        if search(r'^$|^ +$', x)!=None:
                            continue
                        t=x.split('=')
                        if len(t[1].split()) >= 2:
                            print("Config file error")
                            sys.exit(1)
                        else:
                            return t[1]
            except Exception as e:
                print("error: "+str(e))
                ## don't need to kill the service
        return _setup()
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
        if search(r'^$|(root)|0', dd["User"])!=None:
            response={"Allow":False, "Msg":"You are not authorized to use this command"}
    return jsonify(**response)

@plug.route("/AuthZPlugin.AuthZRes", methods=["POST"])
def res():
    response={"Allow":True}
    return jsonify(**response)

def main():
    port=setup(config)
    try:
        plug.run(port=int(port if port != None else "5000"))
    except Exception as e:
        print("Error occcurred " + str(e))
        print("port num: " + port)

if __name__=="__main__":
    main()
