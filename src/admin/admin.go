package admin

import (
    "encoding/json"
    io "io/ioutil"
    re "regexp"
    "github.com/sirupsen/logrus"
    "github.com/go-yaml/yaml"
    "fmt"
)

type Config struct {
    Plug  struct {
        Sock bool `json:"socket"`
        Tcp uint32 `json:"port"`
        Bl []struct {
            Cmd string `json:"cmd"`
            Allow bool `json:"allow"`
            Dmsg string `json:"dmsg"`
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
    dmsg string
    amsg string
    tmpstat bool
}

var jd Config
var mapd Db
var na []nallowed
var config string = "/etc/admin-authz/authz.json"
var db string = "/usr/share/admin-authz/api.yml"

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
    for _, jdata := range jd.Plug.Bl {
        for _,  ydata := range mapd.All {
            for _, cmds := range ydata.Cmd {
                if jdata.Cmd == cmds {
                    na = append(na, nallowed{ydata.Path, ydata.Meth, jdata.Cmd, jdata.Dmsg, jdata.Amsg, jdata.Allow})
                }
            }
        }
    }
    fmt.Printf("%+v\n", jd)
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

func GetStatus(reqm, requ string) (bool, string, string){
    for _, v := range na {
        _status, _ := re.MatchString(v.method, reqm)
        if _status {
            for _, _v := range v.path {
                _status, _ = re.MatchString(_v, requ)
                if ! _status {
                    continue
                }
                if ! v.tmpstat {
                    if jd.Plug.Desc {
                        return true, v.dmsg, v.amsg
                    } else {
                        return true, "", ""
                    }
                }
                return false, "", ""
            }
        }
    }
    return false, "", ""
}
