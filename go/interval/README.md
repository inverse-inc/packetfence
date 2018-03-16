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
	interval.Every("10s").Run(job1)
      
	//define our second job
	job2 := func() {
		fmt.Println("#2 >>> ", time.Now().UTC())
	}
	// Run our first job every 500 milli-seconds, runs concurrently
	interval.Every("500ms").Run(job2)


	// Keep the program from not exiting.
	runtime.Goexit()
}
```

## How it works?
By specifying the chain of calls, a `Job` struct is instantiated and a goroutine is starts observing the `Job`.

The goroutine will be on pause until:
* The next run interval is due. This will cause to execute the job.
* The `SkipWait` channel is activated. This will cause to execute the job.
* The `Quit` channel is activated. This will cause to finish the job.
