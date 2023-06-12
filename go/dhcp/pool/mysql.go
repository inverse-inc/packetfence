package pool

import (
	"context"
	"database/sql"
	"errors"
	"math"
	"strconv"
	"sync"

	//Import mysql as _
	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/go-utils/log"
	"gopkg.in/alexcesaro/statsd.v2"
)

// Mysql struct
type Mysql struct {
	PoolName string
	DHCPPool *DHCPPool
	SQL      *sql.DB
}

// NewMysqlPool return a new mysql pool
func NewMysqlPool(context context.Context, capacity uint64, name string, algorithm int, StatsdClient *statsd.Client, sql *sql.DB) (Backend, error) {
	dp := &Mysql{}
	dp.PoolName = name
	dp.SQL = sql
	dp.NewDHCPPool(context, capacity, algorithm, StatsdClient)
	return dp, nil
}

// NewDHCPPool initialize the DHCPPool
func (dp *Mysql) NewDHCPPool(context context.Context, capacity uint64, algorithm int, StatsdClient *statsd.Client) {
	log.SetProcessName("pfdhcp")
	ctx := log.LoggerNewContext(context)
	d := &DHCPPool{
		lock:      &sync.RWMutex{},
		free:      make(map[uint64]bool),
		mac:       make(map[uint64]string),
		released:  make(map[uint64]int64),
		algorithm: algorithm,
		capacity:  capacity,
		ctx:       ctx,
		statsd:    StatsdClient,
	}

	_, err := dp.SQL.Exec("DELETE FROM dhcppool WHERE pool_name=?", dp.PoolName)
	if err != nil {
		return
	}
	dp.initializePool(capacity)
	dp.DHCPPool = d

}

const maxBatch = 512 * 512

func (dp *Mysql) initializePool(capacity uint64) {
	start := uint64(0)
	for capacity > maxBatch {
		dp.initializeLargePool(start, maxBatch)
		start += maxBatch
		capacity -= maxBatch
	}

	if capacity <= 1000 {
		_, err := dp.SQL.Exec(
			`
INSERT INTO dhcppool (pool_name, idx, released)
(SELECT ?, num, NOW() FROM (
	WITH RECURSIVE seq AS (SELECT 0 AS num UNION ALL SELECT num + 1 FROM seq WHERE num < ? - 1)
	SELECT num + ? as num FROM seq
) as x)
`,
			dp.PoolName,
			capacity,
			start,
		)

		_ = err

		return
	}

	if capacity <= maxBatch {
		dp.initializeLargePool(start, capacity)
	}

}

func (dp *Mysql) initializeLargePool(start, capacity uint64) {
	split := uint64(math.Ceil(math.Sqrt(float64(capacity))))
	_, _ = dp.SQL.Exec(
		`
	INSERT INTO dhcppool (pool_name, idx, released)
	(SELECT ?, num + ?, NOW() FROM (
			WITH RECURSIVE seq AS (SELECT 0 AS num UNION ALL SELECT num + 1 FROM seq WHERE num < ? - 1)
			SELECT a.num * ? + b.num AS num FROM seq AS a JOIN seq AS b ORDER BY a.num, b.num
		) as x WHERE num < ?);
	`,
		dp.PoolName,
		start,
		split,
		split,
		capacity,
	)
}

// GetDHCPPool return the DHCPPool
func (dp *Mysql) GetDHCPPool() DHCPPool {
	return *dp.DHCPPool
}

// ReserveIPIndex reserves an IP in the pool, returns an error if the IP has already been reserved
func (dp *Mysql) ReserveIPIndex(index uint64, mac string) (string, error) {
	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "ReserveIPIndex")

	if index >= dp.DHCPPool.capacity {
		return FreeMac, errors.New("Trying to reserve an IP that is outside the capacity of this pool")
	}
	query := "UPDATE dhcppool SET free = 0, mac = ? WHERE idx = ? AND free = 1 AND pool_name = ?"
	res, err := dp.SQL.Exec(query, mac, index, dp.PoolName)

	if err != nil {
		return FreeMac, errors.New("IP is already reserved")
	}
	count, err2 := res.RowsAffected()
	if err2 != nil {
		return FreeMac, errors.New("IP is already reserved")
	}
	if count == 1 {
		return mac, nil
	}
	return FreeMac, errors.New("IP is already reserved")
}

// FreeIPIndex frees an IP in the pool, returns an error if the IP is already free
func (dp *Mysql) FreeIPIndex(index uint64) error {
	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "FreeIPIndex")

	if !dp.IndexInPool(index) {
		return errors.New("Trying to free an IP that is outside the capacity of this pool")
	}

	query := "UPDATE dhcppool set free = 1, mac = ?, released = NOW() WHERE idx = ? AND free = 0 AND pool_name = ?"
	res, err := dp.SQL.Exec(query, FreeMac, index, dp.PoolName)

	if err != nil {
		return errors.New("IP is already free")
	}
	count, err2 := res.RowsAffected()
	if err2 != nil {
		return errors.New("IP is already free")
	}
	if count == 1 {
		return nil
	}
	return errors.New("IP is already free")
}

// IsFreeIPAtIndex check if the IP is free at the index
func (dp *Mysql) IsFreeIPAtIndex(index uint64) bool {
	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "IsFreeIPAtIndex")
	if !dp.IndexInPool(index) {
		return false
	}

	query := "SELECT free FROM dhcppool WHERE free = 1 AND idx = ? AND pool_name = ?"
	res, err := dp.SQL.Exec(query, index, dp.PoolName)

	if err != nil {
		return false
	}
	count, err2 := res.RowsAffected()
	if err2 != nil {
		return false
	}
	if count == 1 {
		return true
	}
	return false
}

// GetMACIndex check if the IP is free at the index
func (dp *Mysql) GetMACIndex(index uint64) (uint64, string, error) {
	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "GetMACIndex")
	if !dp.IndexInPool(index) {
		return index, FreeMac, errors.New("The index is not part of the pool")
	}

	rows, err := dp.SQL.Query("SELECT idx, mac FROM dhcppool WHERE idx = ? AND pool_name = ?", index, dp.PoolName)
	defer rows.Close()
	if err != nil {
		return index, FreeMac, nil
	}
	var (
		Index int
		mac   string
	)
	for rows.Next() {
		err := rows.Scan(&Index, &mac)
		if err != nil {
			return index, FreeMac, nil
		}
	}
	return uint64(Index), mac, nil
}

// GetFreeIPIndex returns a free IP address, an error if the pool is full
func (dp *Mysql) GetFreeIPIndex(mac string) (uint64, string, error) {
	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "GetFreeIPIndex")

	Count := dp.FreeIPsRemaining()
	if Count == 0 {
		return 0, FreeMac, errors.New("DHCP pool is full")
	}

	// Search for available index

	tx, err := dp.SQL.Begin()

	if err != nil {
		return 0, FreeMac, err
	}
	var query string

	if dp.DHCPPool.algorithm == OldestReleased {
		query = "UPDATE dhcppool D SET D.mac = ?, D.free = 0 WHERE D.pool_name = ? AND D.idx IN ( SELECT temp.tmpidx FROM ( SELECT idx as tmpidx FROM dhcppool P WHERE P.free = 1 AND P.pool_name = ? ORDER BY released LIMIT 1 ) AS temp )"
	} else {
		query = "UPDATE dhcppool D SET D.mac = ?, D.free = 0 WHERE D.pool_name = ? AND D.idx IN ( SELECT temp.tmpidx FROM ( SELECT idx as tmpidx FROM dhcppool P WHERE P.free = 1 AND P.pool_name = ? ORDER BY RAND() LIMIT 1 ) AS temp )"
	}
	res, err := tx.Exec(query, mac, dp.PoolName, dp.PoolName)

	if err != nil {
		tx.Commit()
		return 0, FreeMac, err

	}

	count, err2 := res.RowsAffected()

	if err2 != nil {
		tx.Commit()
		return 0, FreeMac, err2
	}
	if count == 1 {
		query = "SELECT idx from dhcppool where free = 0 and pool_name = ? and mac = ?"
		rows, err := tx.Query(query, dp.PoolName, mac)
		defer rows.Close()
		if err != nil {
			tx.Commit()
			return 0, FreeMac, err2
		}
		var (
			Index int
		)
		for rows.Next() {
			err := rows.Scan(&Index)
			tx.Commit()
			if err != nil {
				return 0, FreeMac, err
			}
			return uint64(Index), mac, nil
		}
		tx.Commit()
		return 0, FreeMac, errors.New("Not able to fetch the index from the db")
	}
	tx.Commit()
	return 0, FreeMac, errors.New("Doesn't suppose to reach here")

}

// IndexInPool returns whether or not a specific index is in the capacity of the pool
func (dp *Mysql) IndexInPool(index uint64) bool {
	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "IndexInPool")
	return index < dp.DHCPPool.capacity
}

// FreeIPsRemaining returns the amount of free IPs in the pool
func (dp *Mysql) FreeIPsRemaining() uint64 {
	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "FreeIPsRemaining")
	rows, err := dp.SQL.Query("SELECT COUNT(*) FROM dhcppool WHERE free = 1 AND pool_name = ?", dp.PoolName)
	defer rows.Close()

	if err != nil {
		return 0
	}
	var (
		Count int
	)
	for rows.Next() {
		err := rows.Scan(&Count)
		if err != nil {
			return 0
		}
		if Count == 0 {
			return 0
		}
		return uint64(Count)
	}
	return 0
}

// Capacity returns the capacity of the pool
func (dp *Mysql) Capacity() uint64 {
	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "Capacity")
	return dp.DHCPPool.capacity
}

// GetIssues Compare what we have in the cache with what we have in the pool
func (dp *Mysql) GetIssues(macs []string) ([]string, map[uint64]string) {
	dp.DHCPPool.lock.RLock()
	defer dp.DHCPPool.lock.RUnlock()
	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "GetIssues")

	var found bool
	found = false
	var inPoolNotInCache []string
	var duplicateInPool map[uint64]string
	duplicateInPool = make(map[uint64]string)

	var count int
	var saveindex uint64
	for i := uint64(0); i < dp.DHCPPool.capacity; i++ {
		if dp.DHCPPool.free[i] {
			continue
		}
		for _, mac := range macs {
			if dp.DHCPPool.mac[i] == mac {
				found = true
			}
		}
		if !found {
			inPoolNotInCache = append(inPoolNotInCache, dp.DHCPPool.mac[i]+", "+strconv.Itoa(int(i)))
		}
	}
	for _, mac := range macs {
		count = 0
		saveindex = 0

		for i := uint64(0); i < dp.DHCPPool.capacity; i++ {
			if dp.DHCPPool.free[i] {
				continue
			}
			if dp.DHCPPool.mac[i] == mac {
				if count == 0 {
					saveindex = i
				}
				if count == 1 {
					duplicateInPool[saveindex] = mac
					duplicateInPool[i] = mac
				} else if count > 1 {
					duplicateInPool[i] = mac
				}
				count++
			}
		}
	}

	return inPoolNotInCache, duplicateInPool
}

// Listen can act even if the VIP is not here
func (dp *Mysql) Listen() bool {
	return true
}
