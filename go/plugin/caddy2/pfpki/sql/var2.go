package sql

import (
	"errors"
	"net/http"
	"reflect"
	"regexp"
	"strconv"
	"strings"

	jsonv2 "github.com/go-json-experiment/json"
)

type Vars2 struct {
	Cursor int      `schema:"cursor" json:"cursor" default:"0"`
	Limit  int      `schema:"limit" json:"limit" default:"100"`
	Fields []string `schema:"fields" json:"fields" default:"id"`
	Sort   []string `schema:"sort" json:"sort" default:"id ASC"`
	Query  SearchOp `schema:"query" json:"query"`
}

func (vars *Vars2) Sql(class interface{}) (Sql, error) {
	var sql Sql
	var err error
	if sql.Select, err = vars.SqlSelect(class); err != nil {
		return Sql{}, err
	}
	if sql.Order, err = vars.SqlOrder(class); err != nil {
		return Sql{}, err
	}
	if sql.Offset, err = vars.SqlOffset(); err != nil {
		return Sql{}, err
	}
	if sql.Limit, err = vars.SqlLimit(); err != nil {
		return Sql{}, err
	}
	if sql.Where, err = vars.Query.SqlWhere(class); err != nil {
		return Sql{}, err
	}

	return sql, nil
}

func (vars *Vars2) SqlSelect(class interface{}) (string, error) {
	classFields := SqlFields(class)
	if len(vars.Fields) == 0 { // SELECT *
		selectFields := make([]string, 0)
		for _, field := range classFields {
			selectFields = append(selectFields, "`"+field+"`")
		}
		return strings.Join(selectFields[:], ","), nil
	} else {
		selectFields := make([]string, 0)
		var valid bool = false
		for _, field := range vars.Fields {
			if strings.ToLower(field) == "id" {
				selectFields = append(selectFields, "`id`")
			} else {
				valid = false
				for c, classField := range classFields {
					if strings.ToLower(classField) == strings.ToLower(field) {
						selectFields = append(selectFields, "`"+classField+"`")
						classFields = append(classFields[:c], classFields[c+1:]...) // pop to avoid reuse (unique)
						valid = true
						break
					}
				}
				if valid == false {
					err := errors.New("Unknown field `" + field + "`")
					return "", err
				}
			}
		}
		return strings.Join(selectFields, ","), nil
	}
}

func (vars *Vars2) SqlOrder(class interface{}) (string, error) {
	if len(vars.Sort) == 0 {
		f, _ := reflect.TypeOf(vars).Elem().FieldByName("Sort")
		vars.Sort = append(vars.Sort, f.Tag.Get("default"))
	}

	classFields := SqlFields(class)
	orderFields := make([]string, 0)
	var valid bool = false
	for _, sort := range vars.Sort {
		s := strings.Split(sort, " ")
		field := s[0]
		order := "ASC"
		if len(s) > 1 {
			if matched, _ := regexp.MatchString(`(?i)desc`, s[1]); matched {
				order = "DESC"
			}
		}
		if strings.ToLower(field) == "id" {
			orderFields = append(orderFields, "`id` "+order)
		} else {
			valid = false
			for c, classField := range classFields {
				if strings.ToLower(classField) == strings.ToLower(field) {
					orderFields = append(orderFields, "`"+classField+"` "+order)
					classFields = append(classFields[:c], classFields[c+1:]...) // pop to avoid reuse (unique)
					valid = true
					break
				}
			}
			if valid == false {
				err := errors.New("Unknown field `" + field + "`")
				return "", err
			}
		}
	}

	return strings.Join(orderFields, ","), nil
}

func (vars *Vars2) SqlOffset() (int, error) {
	var defaultCursor int
	var err error
	if vars.Cursor < 0 {
		f, _ := reflect.TypeOf(vars).Elem().FieldByName("Cursor")

		if defaultCursor, err = strconv.Atoi(f.Tag.Get("default")); err != nil {
			return 0, err
		}
		return defaultCursor, nil
	}

	return vars.Cursor, nil
}

func (vars *Vars2) SqlLimit() (int, error) {
	var defaultLimit int
	var err error
	if vars.Limit <= 0 {
		f, _ := reflect.TypeOf(vars).Elem().FieldByName("Limit")
		if defaultLimit, err = strconv.Atoi(f.Tag.Get("default")); err != nil {
			return 0, err
		}

		return defaultLimit, nil
	}

	return vars.Limit, nil
}

func VarsFromHttpRequest(req *http.Request) (*Vars2, error) {
	vars := Vars2{}
	defer req.Body.Close()
	err := jsonv2.UnmarshalRead(
		req.Body,
		&vars,
		jsonv2.WithUnmarshalers(SearchOpFromUnmarshalers),
	)

	if err != nil {
		return nil, err
	}

	return &vars, nil
}
