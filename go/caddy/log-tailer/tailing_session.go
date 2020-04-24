package logtailer

import (
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/hpcloud/tail"
	"github.com/jcuga/golongpoll"
)

type TailingSession struct {
	files      []string
	tailers    []*tail.Tail
	doneChan   chan int
	lastUsedAt time.Time
}

func NewTailingSession(files []string) *TailingSession {
	ts := &TailingSession{
		files: files,
	}
	return ts
}

func (ts *TailingSession) Touch() {
	ts.lastUsedAt = time.Now()
}

func (ts *TailingSession) Start(sessionId string, publishTo *golongpoll.LongpollManager) error {
	ts.doneChan = make(chan int, len(ts.files))

	for _, file := range ts.files {
		config := tail.Config{Follow: true, ReOpen: true, Location: &tail.SeekInfo{Offset: -10, Whence: os.SEEK_END}}
		t, err := tail.TailFile(file, config)
		if err != nil {
			ts.Stop()
			return err
		}

		go func(t *tail.Tail) {
			for {
				select {
				case <-ts.doneChan:
					t.Stop()
					return
				case line := <-t.Lines:
					publishTo.Publish(sessionId, gin.H{"raw": line.Text})
				}
			}
		}(t)
	}

	return nil
}

func (ts *TailingSession) Stop() {
	for i := range ts.files {
		ts.doneChan <- i
	}
}
