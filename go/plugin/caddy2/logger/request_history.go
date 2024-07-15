package caddylog

import (
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"strconv"

	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/requesthistory"
	"github.com/julienschmidt/httprouter"
)

type RequestHistoryController struct {
	router         *httprouter.Router
	requestHistory *requesthistory.RequestHistory
}

func NewRequestHistoryController(rh *requesthistory.RequestHistory) *RequestHistoryController {
	rhc := &RequestHistoryController{}
	rhc.requestHistory = rh

	rhc.router = httprouter.New()
	rhc.router.GET("/request_history/:requestId", rhc.handleRequestHistoryGetRequest)
	rhc.router.GET("/request_history", rhc.handleRequestHistoryList)

	return rhc
}

func (rhc *RequestHistoryController) handleRequestHistoryList(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	limitStr := r.URL.Query().Get("limit")

	var limit uint64
	if limitStr != "" {
		var err error
		limit, err = strconv.ParseUint(limitStr, 10, 64)
		sharedutils.CheckError(err)
	} else {
		limit = math.MaxUint64
	}

	requests := make([]*requesthistory.Request, 0, 0)

	iterator := rhc.requestHistory.Iterator()
	for i := uint64(0); i < limit; i++ {
		r := iterator.Next()
		if r != nil {
			requests = append(requests, r)
		} else {
			break
		}
	}

	jsonResult, err := json.Marshal(requests)
	sharedutils.CheckError(err)
	io.WriteString(w, string(jsonResult))
}

func (rhc *RequestHistoryController) handleRequestHistoryGetRequest(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	requestId := p.ByName("requestId")
	request, err := rhc.requestHistory.GetRequestByUuid(requestId)
	if err != nil {
		io.WriteString(w, fmt.Sprintf("An error occured while getting request with UUID %s.", requestId))
		return
	}
	jsonResult, err := json.Marshal(request)
	sharedutils.CheckError(err)
	io.WriteString(w, string(jsonResult))
}
