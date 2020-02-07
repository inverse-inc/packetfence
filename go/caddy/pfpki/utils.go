package pfpki

import (
	"crypto/tls"
	"io"
	"reflect"
	"regexp"
	"strconv"
	"strings"

	gomail "gopkg.in/gomail.v2"
)

func email(cert Cert, profile Profile, file []byte, password string) (Info, error) {
	Information := Info{}
	m := gomail.NewMessage()
	m.SetHeader("From", profile.P12MailFrom)
	m.SetHeader("To", cert.Mail)
	m.SetHeader("Subject", profile.P12MailSubject)
	// m.SetBody("text/html", profile.P12MailHeader)
	if profile.P12MailPassword == 1 {
		m.SetBody("text/html", password)
		Information.Password = password
	}
	// m.SetBody("text/html", profile.P12MailFooter)
	m.Attach("cert.p12", gomail.SetCopyFunc(func(w io.Writer) error {
		_, err := w.Write(file)
		return err
	}))

	d := gomail.NewDialer(profile.P12SmtpServer, 25, "user", "123456")
	d.TLSConfig = &tls.Config{InsecureSkipVerify: true}

	if err := d.DialAndSend(m); err != nil {
		return Information, err
	}

	return Information, nil
}

func (params PostVars) Sanitize(class interface{}) GetVars {
	var normalized GetVars
	normalized.Cursor = params.Cursor
	normalized.Limit = params.Limit
	if len(params.Sort) > 0 {
		normalized.Sort = strings.Join(params.Sort[:], ",")
	}
	if len(params.Fields) > 0 {
		normalized.Fields = strings.Join(params.Fields[:], ",")
	}
	normalized.Query = params.Query
	return normalized.Sanitize(class)
}

func (params GetVars) Sanitize(class interface{}) GetVars {
	var sane GetVars
	if params.Cursor <= 0 {
		f, _ := reflect.TypeOf(params).FieldByName("Cursor")
		if defaultCursor, err := strconv.Atoi(f.Tag.Get("default")); err == nil {
			sane.Cursor = defaultCursor
		}
	} else {
		sane.Cursor = params.Cursor
	}
	if params.Limit <= 0 {
		f, _ := reflect.TypeOf(params).FieldByName("Limit")
		if defaultLimit, err := strconv.Atoi(f.Tag.Get("default")); err == nil {
			sane.Limit = defaultLimit
		}
	} else {
		sane.Limit = params.Limit
	}
	if params.Fields == "" {
		sane.Fields = sanitizeFields(strings.Join(jsonFields(class)[:], ","), class)
	} else {
		sane.Fields = sanitizeFields(params.Fields, class)
	}
	if params.Sort == "" {
		f, _ := reflect.TypeOf(params).FieldByName("Sort")
		sane.Sort = f.Tag.Get("default")
	} else {
		sane.Sort = sanitizeSort(params.Sort, class)
	}
	if !reflect.DeepEqual(params.Query, Search{}) {
		sane.Query = sanitizeQuery(params.Query, class)
	}
	return sane
}

func jsonFields(class interface{}) []string {
	tags := make([]string, 0)
	tags = append(tags, "id")
	fields := reflect.TypeOf(class)
	numFields := fields.NumField()
	for i := 0; i < numFields; i++ {
		if jsonTag := fields.Field(i).Tag.Get("json"); jsonTag != "" && jsonTag != "-" {
			if commaIdx := strings.Index(jsonTag, ","); commaIdx > 0 {
				jsonTag = jsonTag[:commaIdx]
			}
			tags = append(tags, jsonTag)
		}
	}
	return tags
}

func sanitizeFields(fields string, class interface{}) string {
	jsonFields := jsonFields(class)
	sane := make([]string, 0)
	queryFields := strings.Split(fields, ",")
	for i := 0; i < len(queryFields); i++ {
		if queryFields[i] == "id" {
			sane = append(sane, "`id`")
		} else {
			for j := 0; j < len(jsonFields); j++ {
				if jsonFields[j] == queryFields[i] {
					sane = append(sane, "`"+jsonFields[j]+"`")
					jsonFields = append(jsonFields[:j], jsonFields[j+1:]...)
					j-- // pop from stack to avoid reuse (make unique)
				}
			}
		}
	}
	return strings.Join(sane[:], ",")
}

func sanitizeSort(sorts string, class interface{}) string {
	jsonFields := jsonFields(class)
	sane := make([]string, 0)
	sortFields := strings.Split(sorts, ",")
	for i := 0; i < len(sortFields); i++ {
		s := strings.Split(sortFields[i], " ")
		field := s[0]
		order := "ASC" // default
		if len(s) > 1 {
			if matched, _ := regexp.MatchString(`(?i)desc`, s[1]); matched {
				order = "DESC"
			}
		}
		if field == "id" {
			sane = append(sane, "`id` "+order)
		} else {
			for j := 0; j < len(jsonFields); j++ {
				if jsonFields[j] == field {
					sane = append(sane, "`"+field+"` "+order)
					jsonFields = append(jsonFields[:j], jsonFields[j+1:]...)
					j-- // pop from stack to avoid reuse (make unique)
				}
			}
		}
	}
	if strings.Join(sane[:], ",") == "" {
		return "`id` ASC"
	}
	return strings.Join(sane[:], ",")
}

func sanitizeQuery(search Search, class interface{}) Search {
	jsonFields := jsonFields(class)
	var sane Search
	if len(search.Values) > 0 {
		if len(search.Values) == 1 {
			return sanitizeQuery(search.Values[0], class)
		} else {
			if matched, _ := regexp.MatchString(`(?i)(and|or)`, search.Op); matched {
				sane.Op = search.Op
				for _, value := range search.Values {
					s := sanitizeQuery(value, class)
					if !reflect.DeepEqual(s, Search{}) {
						sane.Values = append(sane.Values, value)
					}
				}
			}
		}
	} else {
		if matched, _ := regexp.MatchString(`(?i)(equals|not_equals|starts_with|ends_with|contains|greater_than|greater_than_equals|less_than|less_than_equals)`, search.Op); matched {
			for i := 0; i < len(jsonFields); i++ {
				if jsonFields[i] == search.Field {
					return search
				}
			}
		}
	}
	return sane
}
