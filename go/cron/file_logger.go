package maint

import (
	"context"
	"fmt"
	"github.com/inverse-inc/go-utils/log"
	"os"
)

type FileLogger struct {
	Task
	Outfile string
	Content string
}

func NewFileLogger(config map[string]interface{}) JobSetupConfig {
	return &FileLogger{
		Task:    SetupTask(config),
		Outfile: config["outfile"].(string),
		Content: config["content"].(string),
	}
}

func (j *FileLogger) Run() {
	// If the file doesn't exist, create it, or append to the file
	f, err := os.OpenFile(j.Outfile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.LogError(context.Background(), fmt.Sprintf("Cannot open file %s", j.Outfile))
		return
	}

	defer f.Close()
	if _, err := f.Write([]byte(j.Content)); err != nil {
		log.LogError(context.Background(), fmt.Sprintf("Cannot write to file %s", j.Outfile))
	}

}
