package pool

import (
	"context"
	"database/sql"
	"errors"
	"sync"

	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/packetfence/go/log"
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
	dp := Mysql{}
	dp.PoolName = name
	dp.SQL = sql
	dp.NewDHCPPool(context, capacity, algorithm, StatsdClient)
	return &dp, nil
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
	rows, _ := dp.SQL.Query("DELETE FROM dhcppool WHERE pool_name=?", dp.PoolName)
	rows.Close()
	for i := uint64(0); i < capacity; i++ {
		// Need to test err
		rows, _ := dp.SQL.Query("INSERT INTO dhcppool (pool_name, idx) VALUES (?, ?) ON DUPLICATE KEY UPDATE id=id", dp.PoolName, i)
		rows.Close()
	}
	dp.DHCPPool = d
}

// GetDHCPPool return the DHCPPool
func (dp *Mysql) GetDHCPPool() DHCPPool {
	return *dp.DHCPPool
}

// ReserveIPIndex reserves an IP in the pool, returns an error if the IP has already been reserved
func (dp *Mysql) ReserveIPIndex(index uint64, mac string) (string, error) {
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "ReserveIPIndex")

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
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "FreeIPIndex")

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
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "IsFreeIPAtIndex")
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
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "GetMACIndex")
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
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "GetFreeIPIndex")

	Count := dp.FreeIPsRemaining()
	if Count == 0 {
		return 0, FreeMac, errors.New("DHCP pool is full")
	}

	// Search for available index

	tx, err := dp.SQL.Begin()

	if err != nil {
		return 0, FreeMac, err
	}

	// Need to implement algo

	query := "UPDATE dhcppool D SET D.mac = ?, D.free = 0 WHERE D.pool_name = ? AND D.idx IN ( SELECT temp.tmpidx FROM ( SELECT idx as tmpidx FROM dhcppool P WHERE P.free = 1 AND P.pool_name = ? ORDER BY RAND() LIMIT 1 ) AS temp ) AND @tmp_index := idx"
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
		query = "SELECT @tmp_index"
		rows, err := tx.Query(query)
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
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "IndexInPool")
	return index < dp.DHCPPool.capacity
}

// FreeIPsRemaining returns the amount of free IPs in the pool
func (dp *Mysql) FreeIPsRemaining() uint64 {
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "FreeIPsRemaining")
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
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "Capacity")
	return dp.DHCPPool.capacity
}

// GetIssues Compare what we have in the cache with what we have in the pool
func (dp *Mysql) GetIssues(macs []string) ([]string, map[uint64]string) {
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "GetIssues")
	var inPoolNotInCache []string
	var duplicateInPool map[uint64]string
	duplicateInPool = make(map[uint64]string)

	// TODO
	return inPoolNotInCache, duplicateInPool
}

// Listen can act even if the VIP is not here
func (dp *Mysql) Listen() bool {
	return true
}

// Track timing for each function
func (dp *Mysql) timeTrack(t statsd.Timing, name string) {
	t.Send("pfdhcp." + name)
}
