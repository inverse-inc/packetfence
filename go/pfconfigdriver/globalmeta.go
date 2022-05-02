package pfconfigdriver

import "sync"

var globalMeta globalMetaStruct

type globalMetaStruct struct {
	sync.RWMutex
	phoneInAtLeast     float64
	reloadedTouchCache float64
	lastTouchCache     float64
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
}

func init() {
	globalMeta = globalMetaStruct{
		phoneInAtLeast: 5,
	}
}
