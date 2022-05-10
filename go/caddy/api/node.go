package api

import (
	"net/http"

	"github.com/davecgh/go-spew/spew"
	"github.com/inverse-inc/packetfence/go/fbcollectorclient"
	"github.com/julienschmidt/httprouter"
)

func (h APIHandler) nodeFingerbankCommunications(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	spew.Dump(fbcollectorclient.DefaultClient)
}
