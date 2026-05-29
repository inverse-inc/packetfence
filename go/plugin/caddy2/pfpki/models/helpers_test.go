package models_test

import (
	"math/big"
	"time"
)

func bigOne() *big.Int   { return big.NewInt(1) }
func bigTwo() *big.Int   { return big.NewInt(2) }
func timeNow() time.Time { return time.Now() }
func timeNowPlus(days int) time.Time {
	return time.Now().AddDate(0, 0, days)
}
