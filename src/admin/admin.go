package admin

import (
    "encoding/json"
    io "io/ioutil"
    re "regexp"
    "github.com/sirupsen/logrus"
    "github.com/go-yaml/yaml"
)

type Config struct {
    Plug  struct {
        Sock bool `json:"socket"`
        Tcp uint32 `json:"port"`
        Bl []struct {
            Cmd string `json:"cmd"`
            Msg string `json:"msg"`
            Amsg string `json:"admin-msg"`
        } `json:"commands"`
        Desc bool `json:"description"`
    } `json:"plugin"`
}

type Db struct {
    All []struct {
        Cmd []string `yaml:"commands"`
        Meth string `yaml:"method"`
        Path []string `yaml:"path"`
    } `yaml:"methods"`
}

type nallowed struct {
    path []string
    method string
    command string
}

var jd Config
var mapd Db
var na []nallowed
var config string = "/mnt/data/raw_projects/authz-plugin/src/test.json"
var db string = "/mnt/data/raw_projects/authz-plugin/src/det.yml"

func init(){
    con, err := io.ReadFile(config)
    if err != nil {
        logrus.Fatal(err)
    }
    _err := json.Unmarshal([]byte(con), &jd)
    if _err != nil {
        logrus.Fatal(_err)
    }
    _con, __err := io.ReadFile(db)
    if __err != nil {
        logrus.Fatal(__err)
    }
    ___err := yaml.Unmarshal([]byte(_con), &mapd)
    if ___err != nil {
        logrus.Fatal(___err)
    }
    for i, _ := range jd.Plug.Bl {
        for _i, _ := range mapd.All {
            for _, v := range mapd.All[_i].Cmd {
                if jd.Plug.Bl[i].Cmd == v {
                    na = append(na, nallowed{mapd.All[_i].Path, mapd.All[_i].Meth, v})
                }
            }
        }
    }
}


func GetPort() uint32 {
    return jd.Plug.Tcp
}

func GetSockStat() bool {
    return jd.Plug.Sock
}

func GetDescStat() bool {
    return jd.Plug.Desc
}

func CompMeth(req string) bool {
    for i, _ := range na {
        status, _ := re.MatchString(na[i].method, req)
        if status {
            logrus.Info("method matched")
            return true
        }
    }
    return false
}

func CompURI(req string) (bool, int) {
    for i, _ := range na {
        for _, v := range na[i].path {
            status, _ := re.MatchString(v, req)
            if status {
                logrus.Info("uri matched")
                return true, i
            }
        }
    }
    return false, -1
}

func GetMsg(i int) string {
    if i == -1 {
        return ""
    }
    for _i, _ := range jd.Plug.Bl {
        if jd.Plug.Bl[_i].Cmd == na[i].command {
            if jd.Plug.Bl[_i].Msg == "" {
                return "Permission error"
            }
            return jd.Plug.Bl[_i].Msg
        }
    }
    return ""
}

func GetAdminMsg(i int) string {
    if i == -1 {
        return ""
    }
    for _i, _ := range jd.Plug.Bl {
        if jd.Plug.Bl[_i].Cmd == na[i].command {
            if jd.Plug.Bl[_i].Amsg == "" {
                return "This command is admin restricted"
            }
            return jd.Plug.Bl[_i].Amsg
        }
    }
    return ""
}
