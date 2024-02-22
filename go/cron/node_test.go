package maint

import "fmt"

func NewNode(status string) (string, error) {
	mac := ""
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
LIMIT 1
RETURNING mac
;
`
	db, err := getDb()
	if err != nil {
		return "", err
	}
	stmt, err := db.Prepare(sql)
	if err != nil {
		fmt.Printf("Error preparing\n")
		return "", err
	}

	err = stmt.QueryRow(status).Scan(&mac)
	if err != nil {
		fmt.Printf("Mac: %s\n", mac)
		return "", err
	}
	return mac, nil

	/*
		rows, err := db.Query(sql, status)
		if err != nil {
			return "", err
		}
		defer rows.Close()
		if !rows.Next() {
			return "", errors.New("Not found")
		}

		err = rows.Scan(&mac)
		if err != nil {
			return "", err
		}
	*/
}
