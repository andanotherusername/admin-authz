package main

import (
	"github.com/docker/go-plugins-helpers/authorization"
    "admin"
)

type authz struct {
    name string
    port uint32
    socket bool
    desc bool
}

func newPlugin() (*authz, error) {
    return &authz{name: "admin-authz", port: admin.GetPort(), socket: admin.GetSockStat(), desc: admin.GetDescStat()}, nil
}

func (plug *authz) AuthZReq(req authorization.Request) authorization.Response {
    ret, i := admin.CompURI(req.RequestURI)
    if admin.CompMeth(req.RequestMethod) && ret {
        if admin.GetDescStat() {
            return authorization.Response{Allow: false, Msg: admin.GetAdminMsg(i)}
        }
        return authorization.Response{Allow: false, Msg: admin.GetMsg(i)}
    }
    return authorization.Response{Allow: true}
}

func (p *authz) AuthZRes(req authorization.Request) authorization.Response {
	return authorization.Response{Allow: true}
}
