package settings

import (
	"sync"
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
