package pfpki

import (
	"fmt"
	"regexp"
	"strings"
)

func (search Search) Where() Where {
	var where Where
	if len(search.Values) > 0 {
		if len(search.Values) == 1 {
			return search.Values[0].Where()
		} else {
			if matched, _ := regexp.MatchString(`(?i)(and|or)`, search.Op); matched {
				query := make([]string, 0)
				for _, value := range search.Values {
					w := value.Where()
					query = append(query, w.Query)
					where.Values = append(where.Values, w.Values...)
				}
				switch strings.ToLower(search.Op) {
				case "or":
					where.Query = fmt.Sprintf("(%s)", strings.Join(query[:], " OR "))
				case "and":
					fallthrough
				default:
					where.Query = fmt.Sprintf("(%s)", strings.Join(query[:], " AND "))
				}
			}
		}
	} else {
		switch strings.ToLower(search.Op) {
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
		case "equals":
			fallthrough
		default:
			where.Query = "`" + search.Field + "` = ?"
			where.Values = append(where.Values, search.Value)
		}
	}
	return where
}
