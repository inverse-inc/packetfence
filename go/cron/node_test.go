package maint

import (
	"fmt"
	"testing"
)

func NewNode(status string) (string, error) {
	macs, err := NewNodes(status, 1)
	if err != nil {
		return "", nil
	}

	return macs[0], nil
}

func TestNewNodes(t *testing.T) {
	macs, err := NewNodes("reg", 10)
	if err != nil {
		t.Fatalf("NewNodes: %s", err.Error())
	}

	if len(macs) != 10 {
		t.Fatalf("NewNodes did not return 10 nodes")
	}

}

func NewNodes(status string, amount int) ([]string, error) {
	sql := `
INSERT INTO node (
    mac, status
)

SELECT
    LOWER(CONCAT_WS(
        ':',
        LPAD(HEX((seq >> 40) & 255), 2, '0'),
        LPAD(HEX((seq >> 32) & 255), 2, '0'),
        LPAD(HEX((seq >> 24) & 255), 2, '0'),
        LPAD(HEX((seq >> 16) & 255), 2, '0'),
        LPAD(HEX((seq >> 8) & 255), 2, '0'),
        LPAD(HEX(seq & 255), 2, '0')
    )) AS mac , ? as status
FROM (
    SELECT
        seq + 1 as seq,
        LEAD(seq, 1) OVER (ORDER BY seq) as next
    FROM (
        SELECT
        (CONV(REPLACE(mac, ':', ''), 16, 10) ) as seq
        FROM node
        ORDER BY mac
    ) AS a
    ORDER BY seq
) as b
WHERE next != seq
LIMIT ?
RETURNING mac
;
`
	db, err := getDb()
	if err != nil {
		return nil, err
	}
	stmt, err := db.Prepare(sql)
	if err != nil {
		fmt.Printf("Error preparing\n")
		return nil, err
	}

	rows, err := stmt.Query(status, amount)
	if err != nil {
		return nil, err
	}

	macs := make([]string, 0, amount)
	for rows.Next() {
		mac := ""
		err = rows.Scan(&mac)
		if err != nil {
			return nil, err
		}

		macs = append(macs, mac)
	}

	return macs, nil
}
