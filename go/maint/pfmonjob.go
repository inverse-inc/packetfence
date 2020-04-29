package maint

import (
    "os/exec"
)

type PfmonJob struct {
    Name string
    TimeSpec string
}

func NewPfmonJob(name string, timeSpec string) *PfmonJob {
    return &PfmonJob{Name:name, TimeSpec: timeSpec}
}

func (j *PfmonJob) Run() {
    cmd := exec.Command("/usr/local/pf/bin/pfcmd", "pfmon", j.Name)
    err := cmd.Run()
    _ = err
}

func (j *PfmonJob) Spec() string {
    return j.TimeSpec
}
