# interval

Job intervals made easy.

Interval allows you to schedule recurrent jobs with an easy-to-read syntax.

## How to use?
```go
package main

import (
	"fmt"
	"runtime"
	"time"

	"github.com/inverse-inc/packetfence/go/interval"
)

func main() {
	//define our first job
	job1 := func() {
		fmt.Println("#1 >>>", time.Now().UTC())
	}
	// Run our first job every 10 seconds, uses time.ParseDuration
	_, err := interval.Every("10s").Run(job1)
	if err != nil {
		fmt.Printf("%v\n", err)
		return
	}
	  
	//define our second job
	job2 := func() {
		fmt.Println("#2 >>> ", time.Now().UTC())
	}
	// Run our second job every 500 milli-seconds, waits a random amount of time (0 to interval) before starting, runs concurrently
	_, err := interval.Every("500ms").Randomize().Run(job2)
	if err != nil {
		fmt.Printf("%v\n", err)
		return
	}

	// Keep the program from not exiting.
	runtime.Goexit()
}
```

## How it works?
By specifying the chain of calls, a `Job` struct is instantiated and a Goroutine is started observing the `Job`. By calling specifically `.Randomize()` you can wait a random amount of time before starting the job to avoid running mulitple jobs with the same interval at exactly the same time.

```go
interval.Every("500ms").Randomize().Run(job2)
```

The Goroutine will be on pause until:
* The next run interval is due. This will cause to execute the job.
* The `SkipWait` channel is activated. This will cause to execute the job.
* The `Quit` channel is activated. This will cause to finish the job.
