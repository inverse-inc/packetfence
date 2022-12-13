package settings

import (
	"context"
	"fmt"
	"strings"
	"sync"

	"github.com/inverse-inc/go-utils/log"
)

var ActiveDynReverse = sync.Map{}

func ClearFromActiveDynReverse(r *Remote) bool {
	cleared := false
	ActiveDynReverse.Range(func(k, v interface{}) bool {
		entry := v.(*Remote)
		if entry.String() == r.String() {
			ActiveDynReverse.Delete(k)
			cleared = true
			return false
		}
		return true
	})
	return cleared
}

func ClearActiveDynReverseConnector(ctx context.Context, id string) {
	ActiveDynReverse.Range(func(kInt, v interface{}) bool {
		k := kInt.(string)
		if strings.HasPrefix(k, id) {
			log.LoggerWContext(ctx).Debug(fmt.Sprintf("Clearing %s from ActiveDynReverse", k))
			ActiveDynReverse.Delete(k)
		}
		return true
	})
}
