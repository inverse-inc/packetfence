package interval

import (
	"errors"
	"math/rand"
	"sync"
	"time"
)

type scheduled interface {
	nextRun() (time.Duration, error)
}

type Job struct {
	fn        func()
	Quit      chan bool
	SkipWait  chan bool
	err       error
	schedule  scheduled
	isRunning bool
	doRun     func() bool
	sync.RWMutex
}

type recurrent struct {
	randomize bool
	delay     int64
	started   time.Time
	count     int64
	done      bool
}

func (r *recurrent) nextRun() (time.Duration, error) {
	if r.delay < 0 {
		return 0, errors.New("invalid delay")
	}
	if !r.done {
		r.done = true
		return 0, nil
	}
	if r.randomize {
		r.randomize = false
		//add jitter to time started
		jitter := rand.Int63n(r.delay)
		r.started = r.started.Add(-time.Duration(jitter))
	}
	//adjust offset for processing time drift
	offset := (r.count * r.delay) - time.Since(r.started).Nanoseconds()
	return time.Duration(r.delay + offset), nil
}

func Every(duration string) *Job {
	t, err := time.ParseDuration(duration)
	if err != nil {
		return &Job{err: errors.New("Could not parse duration: " + duration)}
	}
	r := new(recurrent)
	r.started = time.Now().UTC()
	r.count = 0
	r.delay = t.Nanoseconds()
	j := new(Job)
	j.schedule = r
	return j
}

// DoRun test if the job need to be run
func (j *Job) DoRun(doRun func() bool) *Job {
	j.doRun = doRun
	return j
}

func (j *Job) Randomize() *Job {
	rj, ok := j.schedule.(*recurrent)
	if !ok {
		j.err = errors.New("bad function chaining")
		return j
	}
	rj.done = true
	rj.randomize = true
	return j
}

func (j *Job) Run(f func()) (*Job, error) {
	if j.err != nil {
		return nil, j.err
	}
	var next time.Duration
	var err error
	j.Quit = make(chan bool, 1)
	j.SkipWait = make(chan bool, 1)
	j.fn = f
	next, err = j.schedule.nextRun()
	if err != nil {
		return nil, err
	}
	go func(j *Job) {
		for {
			select {
			case <-j.Quit:
				return
			case <-j.SkipWait:
				go runJob(j)
			case <-time.After(next):
				go runJob(j)
			}
			next, _ = j.schedule.nextRun()
		}
	}(j)
	return j, nil
}

func runJob(job *Job) {
	rj, ok := job.schedule.(*recurrent)
	if !ok {
		job.err = errors.New("bad function chaining")
		return
	}
	rj.count += 1
	if job.IsRunning() || !job.doRun() {
		return
	}
	job.setRunning(true)
	job.fn()
	job.setRunning(false)
}

func (j *Job) IsRunning() bool {
	j.RLock()
	defer j.RUnlock()
	return j.isRunning
}

func (j *Job) setRunning(running bool) {
	j.Lock()
	defer j.Unlock()
	j.isRunning = running
}
