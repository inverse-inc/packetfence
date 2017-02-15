package main

import (
	"log"
	"net/http"
)

type static struct {
	p *proxy
}

func newStatic(p *proxy) *static {
	return &static{p: p}
}

// run set handlers and launch api
func (static *static) run(port string) {
	http.Handle("/common/", http.FileServer(http.Dir("/usr/local/pf/html")))
	http.Handle("/content/", http.FileServer(http.Dir("/usr/local/pf/html/captive-portal")))
	http.HandleFunc("/favicon.ico", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "/usr/local/pf/html/common/favicon.ico")
	})
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
