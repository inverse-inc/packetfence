package api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/common"
	"github.com/inverse-inc/packetfence/go/fbcollectorclient"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/julienschmidt/httprouter"
)

func (h APIHandler) nodeFingerbankCommunications(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	client := pfconfigdriver.GetRefresh(ctx, "fbcollectorclient").(*fbcollectorclient.ClientFromConfig)
	requestPayload := struct {
		Nodes []string
	}{}

	defer r.Body.Close()
	err := json.NewDecoder(r.Body).Decode(&requestPayload)
	sharedutils.CheckError(err)

	endpoints := map[string]common.CollectorEndpointCommunications{}

	wg := sync.WaitGroup{}
	l := sync.Mutex{}
	for _, mac := range requestPayload.Nodes {
		wg.Add(1)
		go func(mac string) {
			defer wg.Done()
			ed := common.CollectorEndpointCommunications{}
			err := client.Call(ctx, "GET", fmt.Sprintf("/endpoint_data/%s", mac), nil, &ed)
			if err != nil {
				log.LoggerWContext(ctx).Error("Error calling the fingerbank client: %s", err.Error())
			}
			l.Lock()
			defer l.Unlock()
			endpoints[mac] = ed
		}(mac)
	}

	wg.Wait()

	err = json.NewEncoder(w).Encode(gin.H{"items": endpoints})
	sharedutils.CheckError(err)
}
