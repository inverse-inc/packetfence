package logtailer

import (
	"os"
	"regexp"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jcuga/golongpoll"
	"github.com/nxadm/tail"
)

var metaEngine = NewRsyslogMetaEngine()

type TailingSession struct {
	files      []string
	filter     *regexp.Regexp
	tailers    []*tail.Tail
	doneChan   chan int
	lastUsedAt time.Time
}

func NewTailingSession(files []string, filterRe *regexp.Regexp) *TailingSession {
	ts := &TailingSession{
		files:  files,
		filter: filterRe,
	}
	return ts
}

func (ts *TailingSession) Touch() {
	ts.lastUsedAt = time.Now()
}

func (ts *TailingSession) Start(sessionId string, publishTo *golongpoll.LongpollManager) error {
	ts.doneChan = make(chan int, len(ts.files))

	ts.Touch()

	for _, file := range ts.files {
		config := tail.Config{Follow: true, ReOpen: true, Poll: true, Location: &tail.SeekInfo{Offset: 0, Whence: os.SEEK_END}}
		t, err := tail.TailFile(file, config)
		if err != nil {
			ts.Stop()
			return err
		}

		go func(sessionId string, t *tail.Tail) {
			for {
				select {
				case <-ts.doneChan:
					t.Stop()
					return
				case line := <-t.Lines:
					if ts.filter.MatchString(line.Text) {
						meta := metaEngine.ExtractMeta(line.Text)
						meta.Filename = t.Filename
						publishTo.Publish(sessionId, gin.H{"raw": line.Text, "meta": meta})
					}
				}
			}
		}(sessionId, t)
	}

	return nil
}

func (ts *TailingSession) Stop() {
	for i := range ts.files {
		ts.doneChan <- i
	}
}
