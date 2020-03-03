package db

import (
    "strings"
)

type CsvArray []string 

func (a *CsvArray) Scan(src interface{}) {
    if src == nil {
        return
    }
    var tmp string
    switch s := src.(type) {
    case *string:     
        tmp = *s
    case []byte:
        tmp = string(s)
    }

    *a = strings.Split(tmp, ",")
}
