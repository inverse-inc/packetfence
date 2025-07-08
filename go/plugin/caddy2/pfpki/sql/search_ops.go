package sql

import (
	"bytes"
	"fmt"
	"strings"

	jsonv2 "github.com/go-json-experiment/json"

	"github.com/go-json-experiment/json/jsontext"
)

var simpleOps = map[string]string{
	"equals":              "=",
	"not_equals":          "!=",
	"greater_than":        ">",
	"greater_than_equals": ">=",
	"less_than":           "<",
	"less_than_equals":    "<=",
}

type SearchOp interface {
	SqlWhere(class interface{}) (Where, error)
	SqlOp() string
}

func logicalOp(class interface{}, ops []SearchOp, op string) (Where, error) {

	if len(ops) == 0 {
		return Where{Query: "1=1"}, nil
	}

	if len(ops) == 1 {
		return ops[0].SqlWhere(class)
	}

	args := []interface{}{}
	parts := []string{}
	for _, v := range ops {
		w, err := v.SqlWhere(class)
		if err != nil {
			return Where{}, err
		}

		args = append(args, w.Values...)
		parts = append(parts, "("+w.Query+")")
	}

	return Where{Values: args, Query: strings.Join(parts, op)}, nil
}

func betweenOp(op string, class interface{}, field string, values []interface{}) (Where, error) {
	cleanField, err := checkField(class, field)
	if err != nil {
		return Where{}, err
	}

	return Where{
		Query:  fmt.Sprintf("`%s` %s ? AND ?", op, cleanField),
		Values: append([]interface{}{}, values...),
	}, nil
}

type SearchNotBetweenOp struct {
	Op     string         `json:"op"`
	Field  string         `json:"field"`
	Values [2]interface{} `json:"values"`
}

func (s *SearchNotBetweenOp) SqlOp() string {
	return s.Op
}

func (s *SearchNotBetweenOp) SqlWhere(class interface{}) (Where, error) {
	return betweenOp("NOT BETWEEN", class, s.Field, s.Values[:])
}

type SearchBetweenOp struct {
	Op     string         `json:"op"`
	Field  string         `json:"field"`
	Values [2]interface{} `json:"values"`
}

func (s *SearchBetweenOp) SqlOp() string {
	return s.Op
}

func (s *SearchBetweenOp) SqlWhere(class interface{}) (Where, error) {
	return betweenOp("BETWEEN", class, s.Field, s.Values[:])
}

type SearchAndOp struct {
	Op     string     `json:"op"`
	Values []SearchOp `json:"values"`
}

func (s *SearchAndOp) SqlOp() string {
	return s.Op
}

func (s *SearchAndOp) SqlWhere(class interface{}) (Where, error) {
	return logicalOp(class, s.Values, " AND ")
}

type SearchOr struct {
	Op     string     `json:"op"`
	Values []SearchOp `json:"values"`
}

func (s *SearchOr) SqlOp() string {
	return s.Op
}

type SearchContainsOp struct {
	Op    string      `json:"op"`
	Field string      `json:"field"`
	Value interface{} `json:"value"`
}

func (s *SearchContainsOp) SqlOp() string {
	return s.Op
}

func (s *SearchContainsOp) SqlWhere(class interface{}) (Where, error) {
	field, err := checkField(class, s.Field)
	if err != nil {
		return Where{}, err
	}

	return Where{
		Query:  fmt.Sprintf("`%s` LIKE ?", field),
		Values: []interface{}{fmt.Sprintf("%%%s%%", s.Value)},
	}, nil
}

type SearchStartsWithOp struct {
	Op    string `json:"op"`
	Field string `json:"field"`
	Value string `json:"value"`
}

func (s *SearchStartsWithOp) SqlOp() string {
	return s.Op
}

func (s *SearchStartsWithOp) SqlWhere(class interface{}) (Where, error) {
	field, err := checkField(class, s.Field)
	if err != nil {
		return Where{}, err
	}

	return Where{
		Query:  fmt.Sprintf("`%s` LIKE ?", field),
		Values: []interface{}{fmt.Sprintf("%s%%", s.Value)},
	}, nil
}

type SearchEndsWithOp struct {
	Op    string      `json:"op"`
	Field string      `json:"field"`
	Value interface{} `json:"value"`
}

func (s *SearchEndsWithOp) SqlOp() string {
	return s.Op
}

func (s *SearchEndsWithOp) SqlWhere(class interface{}) (Where, error) {
	field, err := checkField(class, s.Field)
	if err != nil {
		return Where{}, err
	}

	return Where{
		Query:  fmt.Sprintf("`%s` LIKE ?", field),
		Values: []interface{}{fmt.Sprintf("%%%s", s.Value)},
	}, nil
}

func checkField(class interface{}, field string) (string, error) {
	classFields := SqlFields(class)
	normalizedField := ""
	var valid bool = false
	for _, classField := range classFields {
		if strings.EqualFold(classField, field) {
			normalizedField = classField
			valid = true
			break
		}
	}

	if valid == false {
		return "", fmt.Errorf("Unknown field `%s`", field)
	}

	return normalizedField, nil

}

func (s *SearchOr) SqlWhere(class interface{}) (Where, error) {
	return logicalOp(class, s.Values, " OR ")
}

type SearchSimpleOP struct {
	Op    string      `json:"op"`
	Field string      `json:"field"`
	sqlOp string      `json:"-"`
	Value interface{} `json:"value"`
}

func (s *SearchSimpleOP) SqlOp() string {
	return s.Op
}

func (s *SearchSimpleOP) SqlWhere(class interface{}) (Where, error) {
	field, err := checkField(class, s.Field)
	if err != nil {
		return Where{}, err
	}

	return Where{
		Query:  fmt.Sprintf("`%s` %s ?", field, s.sqlOp),
		Values: []interface{}{s.Value},
	}, nil
}

type SearchOpWrapper struct {
	Op  string         `json:"op"`
	Val jsontext.Value `json:",unknown"`
}

func (t *SearchOpWrapper) UnmarshalJSONFrom(d *jsontext.Decoder) error {
	if k := d.PeekKind(); k != '{' {
		return fmt.Errorf("Invalid kind: %s", k.String())
	}

	if _, err := d.ReadToken(); err != nil {
		return err
	}

	value := make([]byte, 0, len(d.UnreadBuffer()))
	value = append(value, '{')

	typeFound := false
	fields := 0
	for d.PeekKind() != '}' {
		fields++
		name, err := d.ReadValue()
		if err != nil {
			return err
		}

		value = append(value, name...)
		value = append(value, ':')
		val, err := d.ReadValue()
		if err != nil {
			return err
		}

		value = append(value, val...)
		value = append(value, ',')
		if typeFound {
			continue
		}

		if bytes.Compare(name, []byte(`"op"`)) == 0 {
			if err := jsonv2.Unmarshal(val, &t.Op); err != nil {
				return err
			}
			typeFound = true
		}
	}

	if _, err := d.ReadToken(); err != nil {
		return err
	}

	if fields > 0 {
		value[len(value)-1] = '}'
	} else {
		value = append(value, '}')
	}

	t.Val = jsontext.Value(value)
	return nil
}

func typeUnmarshal[T any](data []byte, opts ...jsontext.Options) (*T, error) {
	var t T
	err := jsonv2.Unmarshal(data,
		&t,
		opts...,
	)
	if err != nil {
		return nil, err
	}

	return &t, nil
}

func (w *SearchOpWrapper) UnmarshmalSearchOp(opts ...jsontext.Options) (SearchOp, error) {
	if simpleOp, found := simpleOps[w.Op]; found {
		t, err := typeUnmarshal[SearchSimpleOP](w.Val, opts...)
		if err != nil {
			return nil, err
		}
		t.sqlOp = simpleOp
		return t, nil
	}

	switch w.Op {
	case "and":
		return typeUnmarshal[SearchAndOp](w.Val, opts...)
	case "or":
		return typeUnmarshal[SearchOr](w.Val, opts...)
	case "starts_with":
		return typeUnmarshal[SearchStartsWithOp](w.Val, opts...)
	case "ends_with":
		return typeUnmarshal[SearchEndsWithOp](w.Val, opts...)
	case "contains":
		return typeUnmarshal[SearchContainsOp](w.Val, opts...)
	case "between":
		return typeUnmarshal[SearchBetweenOp](w.Val, opts...)
	case "not_between":
		return typeUnmarshal[SearchNotBetweenOp](w.Val, opts...)
	default:
		return nil, fmt.Errorf("Unknown type '%s'", w.Op)
	}

}

func SearchOpUnmarshalFromFunc(d *jsontext.Decoder, val *SearchOp) error {
	w := SearchOpWrapper{}
	if err := w.UnmarshalJSONFrom(d); err != nil {
		return err
	}

	if t, err := w.UnmarshmalSearchOp(d.Options()); err != nil {
		return err
	} else {
		*val = t
	}

	return nil
}

var SearchOpFromUnmarshalers *jsonv2.Unmarshalers

func init() {
	SearchOpFromUnmarshalers = jsonv2.UnmarshalFromFunc(SearchOpUnmarshalFromFunc)
}
