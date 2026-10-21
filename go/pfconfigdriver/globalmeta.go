package pfconfigdriver

import "sync"

var globalMeta globalMetaStruct

type globalMetaStruct struct {
	sync.RWMutex
	phoneInAtLeast     float64
	reloadedTouchCache float64
	lastTouchCache     float64
	// The value the last reply carried, whether or not it was kept. See publishLastTouchCache
	reportedTouchCache float64
}

func (gms *globalMetaStruct) getPhoneInAtLeast() float64 {
	gms.RLock()
	defer gms.RUnlock()
	return gms.phoneInAtLeast
}

func (gms *globalMetaStruct) getReloadedTouchCache() float64 {
	gms.RLock()
	defer gms.RUnlock()
	return gms.reloadedTouchCache
}

func (gms *globalMetaStruct) getLastTouchCache() float64 {
	gms.RLock()
	defer gms.RUnlock()
	return gms.lastTouchCache
}

func (gms *globalMetaStruct) setPhoneInAtLeast(phoneInAtLeast float64) {
	gms.Lock()
	defer gms.Unlock()
	gms.phoneInAtLeast = phoneInAtLeast
}

func (gms *globalMetaStruct) setReloadedTouchCache(reloadedTouchCache float64) {
	gms.Lock()
	defer gms.Unlock()
	gms.reloadedTouchCache = reloadedTouchCache
}

func (gms *globalMetaStruct) setLastTouchCache(lastTouchCache float64) {
	gms.Lock()
	defer gms.Unlock()
	gms.lastTouchCache = lastTouchCache
	gms.reportedTouchCache = lastTouchCache
}

// Stores the last touch cache that a reply carried and reports whether it was kept.
// pfconfig only ever moves that value forward, so a reply carrying an older one than the one we
// already have overlapped a reply that landed here first. Keeping the older one would send every
// resource stamped with the newer one back to pfconfig although nothing was expired, so it is
// held back until a second reply reports it, which is what happens when pfconfig itself went
// backwards (its clock stepped, it was restarted with a different one) rather than when two
// fetches crossed.
func (gms *globalMetaStruct) publishLastTouchCache(lastTouchCache float64) bool {
	gms.Lock()
	defer gms.Unlock()
	previouslyReported := gms.reportedTouchCache
	gms.reportedTouchCache = lastTouchCache
	if lastTouchCache < gms.lastTouchCache && lastTouchCache != previouslyReported {
		return false
	}
	gms.lastTouchCache = lastTouchCache
	return true
}

func init() {
	globalMeta = globalMetaStruct{
		phoneInAtLeast: 5,
	}
}
