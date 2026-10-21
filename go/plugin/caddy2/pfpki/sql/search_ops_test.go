package sql

import (
	"testing"

	jsonv2 "github.com/go-json-experiment/json"
	"github.com/google/go-cmp/cmp"
)

func TestQuery(t *testing.T) {
	data := `
{
  "cursor": 0,
  "limit": 1000,
  "query": {
    "op": "and",
    "values": [
      {
        "field": "created_at",
        "op": "between",
        "values": [
          "'.$datum_start.'",
          "'.$datum_einde.'"
        ]
      }
    ]
  }
}
	 `
	var query Vars2

	err := jsonv2.Unmarshal(
		[]byte(data),
		&query,
		jsonv2.WithUnmarshalers(jsonv2.UnmarshalFromFunc(SearchOpUnmarshalFromFunc)),
	)
	if err != nil {
		t.Fatalf("Unable to marshal %s", err.Error())
	}

	if diff := cmp.Diff(
		Vars2{
			Limit: 1000,
			Query: &SearchAndOp{
				Op: "and",
				Values: []SearchOp{
					&SearchBetweenOp{
						Op:    "between",
						Field: "created_at",
						Values: [2]interface{}{
							"'.$datum_start.'",
							"'.$datum_einde.'",
						},
					},
				},
			},
		},
		query,
	); diff != "" {
		t.Fatalf("+wanted -got: %s", diff)
	}

	var class struct {
		CreatedAt string `json:"created_at"`
	}

	sql, err := query.Query.SqlWhere(class)
	if err != nil {
		t.Fatalf("Error: %s", err.Error())
	}
	if diff := cmp.Diff(
		Where{
			Query:  "`created_at` BETWEEN ? AND ?",
			Values: []interface{}{"'.$datum_start.'", "'.$datum_einde.'"},
		},
		sql,
	); diff != "" {
		t.Fatalf("+wanted -got: %s", diff)
	}

	err = jsonv2.Unmarshal([]byte(`
{
  "cursor": 0,
  "fields": [
    "id"
  ],
  "sort": [
    "created_at DESC"
  ],
  "limit": 1,
  "query": {
    "op": "and",
    "values": [
      {
        "op": "or",
        "values": [
          {
            "field": "mac",
            "op": "equals",
            "value": "00:03:00:11:11:01"
          }
        ]
      },
      {
        "op": "or",
        "values": [
          {
            "field": "auth_status",
            "op": "equals",
            "value": "Accept"
          }
        ]
      },
      {
        "op": "or",
        "values": [
          {
            "field": "connection_type",
            "op": "equals",
            "value": "Ethernet-NoEAP"
          }
        ]
      }
    ]
  }
}
	`),
		&query,
		jsonv2.WithUnmarshalers(jsonv2.UnmarshalFromFunc(SearchOpUnmarshalFromFunc)),
	)
	if err != nil {
		t.Fatalf("Unable to marshal %s", err.Error())
	}

	if diff := cmp.Diff(
		Vars2{
			Limit:  1,
			Fields: []string{"id"},
			Sort:   []string{"created_at DESC"},
			Query: &SearchAndOp{
				Op: "and",
				Values: []SearchOp{
					&SearchOrOp{
						Op: "or",
						Values: []SearchOp{
							&SearchSimpleOP{
								Op:        "equals",
								Field:     "mac",
								Value:     "00:03:00:11:11:01",
								RealSqlOp: "=",
							},
						},
					},
					&SearchOrOp{
						Op: "or",
						Values: []SearchOp{
							&SearchSimpleOP{
								Op:        "equals",
								Field:     "auth_status",
								Value:     "Accept",
								RealSqlOp: "=",
							},
						},
					},
					&SearchOrOp{
						Op: "or",
						Values: []SearchOp{
							&SearchSimpleOP{
								Op:        "equals",
								Field:     "connection_type",
								Value:     "Ethernet-NoEAP",
								RealSqlOp: "=",
							},
						},
					},
				},
			},
		},
		query,
	); diff != "" {
		t.Fatalf("+wanted -got: %s", diff)
	}

	var class2 struct {
		ConnectionType string `json:"connection_type"`
		AuthStatus     string `json:"auth_status"`
		Mac            string `json:"mac"`
	}

	sql, err = query.Query.SqlWhere(class2)
	if err != nil {
		t.Fatalf("Error: %s", err.Error())
	}
	if diff := cmp.Diff(
		Where{
			Query: "(`mac` = ?) AND (`auth_status` = ?) AND (`connection_type` = ?)",
			Values: []interface{}{
				"00:03:00:11:11:01",
				"Accept",
				"Ethernet-NoEAP",
			},
		},
		sql,
	); diff != "" {
		t.Fatalf("+wanted -got: %s", diff)
	}

}
