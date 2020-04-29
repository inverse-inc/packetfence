package maint

type Job interface {
    Run()
    Spec() string
}
