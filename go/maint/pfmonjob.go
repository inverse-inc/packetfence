package maint

import (
    "os/exec"
)

type PfmonJob struct {
    Name string
}

func NewPfmonJob(name string) *PfmonJob {
    return &PfmonJob{Name:name}
}

func (j *PfmonJob) Run() {
    cmd := exec.Command("/usr/local/pf/bin/pfcmd", "pfmon", j.Name)
    err := cmd.Run()
    _ = err
}
