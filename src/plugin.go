package main

import (
	auth "github.com/docker/go-plugins-helpers/authorization"
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

func (plug *authz) AuthZReq(req auth.Request) auth.Response {
    nallowed, dmsg, _ := admin.GetStatus(req.RequestMethod, req.RequestURI)
	if nallowed {
		return auth.Response{Allow: false, Msg: dmsg}
	}
    return auth.Response{Allow: true}
}

func (p *authz) AuthZRes(req auth.Request) auth.Response {
	return auth.Response{Allow: true}
}
