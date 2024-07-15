package sql

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"reflect"
	"regexp"
	"strconv"
	"strings"
)

type (
	// SQL struct
	Sql struct {
		Select string
		Order  string
		Offset int
		Limit  int
		Where  Where
	}

	// Where struct
	Where struct {
		Query  string
		Values []interface{}
	}
	Vars struct {
		Cursor int      `schema:"cursor" json:"cursor" default:"0"`
		Limit  int      `schema:"limit" json:"limit" default:"100"`
		Fields []string `schema:"fields" json:"fields" default:"id"`
		Sort   []string `schema:"sort" json:"sort" default:"id ASC"`
		Query  Search   `schema:"query" json:"query"`
	}

	// Search struct
	Search struct {
		Field  string      `schema:"field" json:"field,omitempty"`
		Op     string      `schema:"op" json:"op"`
		Value  interface{} `schema:"value" json:"value,omitempty"`
		Values []Search    `schema:"values" json:"values,omitempty"`
	}
)

func (vars Vars) Sql(class interface{}) (Sql, error) {
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

func SqlFields(class interface{}) []string {
	jsonTags := make([]string, 0)
	jsonTags = append(jsonTags, "id")
	fields := reflect.TypeOf(class)
	numFields := fields.NumField()
	for i := 0; i < numFields; i++ {
		if jsonTag := fields.Field(i).Tag.Get("json"); jsonTag != "" && jsonTag != "-" {
			if commaIdx := strings.Index(jsonTag, ","); commaIdx > 0 {
				jsonTag = jsonTag[:commaIdx]
			}
			jsonTags = append(jsonTags, jsonTag)
		}
	}
	return jsonTags
}

func (vars Vars) SqlSelect(class interface{}) (string, error) {
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

func (vars Vars) SqlOrder(class interface{}) (string, error) {
	if len(vars.Sort) == 0 {
		f, _ := reflect.TypeOf(vars).FieldByName("Sort")
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

func (vars Vars) SqlOffset() (int, error) {
	var defaultCursor int
	var err error
	if vars.Cursor < 0 {
		f, _ := reflect.TypeOf(vars).FieldByName("Cursor")

		if defaultCursor, err = strconv.Atoi(f.Tag.Get("default")); err != nil {
			return 0, err
		}
		return defaultCursor, nil
	} else {
		return vars.Cursor, nil
	}
}

func (vars Vars) SqlLimit() (int, error) {
	var defaultLimit int
	var err error
	if vars.Limit <= 0 {
		f, _ := reflect.TypeOf(vars).FieldByName("Limit")
		if defaultLimit, err = strconv.Atoi(f.Tag.Get("default")); err != nil {
			return 0, err
		}
		return defaultLimit, nil
	} else {
		return vars.Limit, nil
	}
}

func (search Search) SqlWhere(class interface{}) (Where, error) {
	if reflect.DeepEqual(search, Search{}) {
		return Where{}, nil
	}
	var where Where
	var err error
	if len(search.Values) > 0 {
		if len(search.Values) == 1 {
			where, err = search.Values[0].SqlWhere(class)
			return where, nil
		} else if search.Op != "" {
			if matched, _ := regexp.MatchString(`(?i)(and|or)`, search.Op); matched {
				children := make([]string, 0)
				for _, value := range search.Values {
					w, err := value.SqlWhere(class)
					if err != nil {
						return Where{}, err
					}
					if w.Query != "" {
						children = append(children, w.Query)
						where.Values = append(where.Values, w.Values...)
					}
				}
				if len(children) == 0 {
					where.Query = "1=1"
				} else {
					switch strings.ToLower(search.Op) {
					case "and":
						where.Query = fmt.Sprintf("(%s)", strings.Join(children[:], " AND "))
					case "or":
						where.Query = fmt.Sprintf("(%s)", strings.Join(children[:], " OR "))
					default:
						err = errors.New("Unknown operator `" + search.Op + "`")
						return Where{}, err
					}
				}
			}
		}
	} else {
		classFields := SqlFields(class)
		var valid bool = false
		for _, classField := range classFields {
			if strings.ToLower(classField) == strings.ToLower(search.Field) {
				search.Field = classField
				valid = true
				break
			}
		}
		if valid == false {
			err = errors.New("Unknown field `" + search.Field + "`")
			return Where{}, err
		}
		if search.Value != "" {
			switch strings.ToLower(search.Op) {
			case "equals":
				where.Query = "`" + search.Field + "` = ?"
				where.Values = append(where.Values, search.Value)
			case "not_equals":
				where.Query = "`" + search.Field + "` != ?"
				where.Values = append(where.Values, search.Value)
			case "starts_with":
				where.Query = "`" + search.Field + "` LIKE ?"
				where.Values = append(where.Values, search.Value.(string)+"%")
			case "ends_with":
				where.Query = "`" + search.Field + "` LIKE ?"
				where.Values = append(where.Values, "%"+search.Value.(string))
			case "contains":
				where.Query = "`" + search.Field + "` LIKE ?"
				where.Values = append(where.Values, "%"+search.Value.(string)+"%")
			case "greater_than":
				where.Query = "`" + search.Field + "` > ?"
				where.Values = append(where.Values, search.Value)
			case "greater_than_equals":
				where.Query = "`" + search.Field + "` >= ?"
				where.Values = append(where.Values, search.Value)
			case "less_than":
				where.Query = "`" + search.Field + "` < ?"
				where.Values = append(where.Values, search.Value)
			case "less_than_equals":
				where.Query = "`" + search.Field + "` <= ?"
				where.Values = append(where.Values, search.Value)
			default:
				err = errors.New("Unknown operator `" + search.Op + "`")
				return Where{}, err
			}
		}
	}
	return where, nil
}

func (vars *Vars) DecodeBodyJson(req *http.Request) error {
	body, err := io.ReadAll(req.Body)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(body, &vars); err != nil {
		return err
	}
	return nil
}
