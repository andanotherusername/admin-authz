from flask import Flask, jsonify, request
import base64, json, os, pwd
from re import search

plug=Flask(__name__)

users=[]
port=None
cuid=None
config="/etc/admin-authz/authz.conf"

if os.path.isfile(config):
    def setup():
        try:
            with open(config, 'r') as f:
                for x in f.readlines():
                    temp=x.split("=")
                    if temp[0]=="port":
                        global port
                        port=temp[1]
                    elif temp[0]=="users":
                        for xx in temp[1].split():
                            global users
                            users.append(xx)
        except Exception as e:
            print("error occurred: " + str(e))
            ## this isn't serious enough (for now) to kill the service
    setup()

def isrunning(un):
    print("cuid = "+str(cuid))
    if cuid != None:
        print("here")
        print(pwd.getpwnam(un).pw_uid)
        if int(pwd.getpwnam(un).pw_uid) == int(cuid):
            return True
    return False

@plug.route("/Plugin.Activate", methods=["POST"])
def start():
    return jsonify({"Implements": ["authz"]})

@plug.route("/AuthZPlugin.AuthZReq", methods=["POST"])
def req():
    res=json.loads(request.data)
    print(res)
    response={"Allow":True}
    if search(r'/(exec)$', res["RequestUri"]) != None:
        dd=json.loads(base64.b64decode(res["RequestBody"]))
        if search(r'^$|(root)|0', dd["User"])!=None:
            response={"Allow":False, "Err":"You are not authorized to use this command"}
    return jsonify(**response)

@plug.route("/AuthZPlugin.AuthZRes", methods=["POST"])
def res():
    response={"Allow":True}
    return jsonify(**response)

try:
    plug.run(port=int(port if port != None else "5000"))
except Exception as e:
    print("Error occcurred " + str(e))
    print("port num: " + port)
