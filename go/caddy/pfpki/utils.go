package pfpki

import (
	"crypto/tls"
	"fmt"
	"html/template"
	"io"
	"reflect"
	"regexp"
	"strconv"
	"strings"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	gomail "gopkg.in/gomail.v2"
)

type Email struct {
	Header   string
	Footer   string
	Password string
}

const emailTemplate = `<!doctype html><html xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office"><head><title></title><!--[if !mso]><!-- --><meta http-equiv="X-UA-Compatible" content="IE=edge"><!--<![endif]--><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style type="text/css">#outlook a { padding:0; }
body { margin:0;padding:0;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%; }
table, td { border-collapse:collapse;mso-table-lspace:0pt;mso-table-rspace:0pt; }
img { border:0;height:auto;line-height:100%; outline:none;text-decoration:none;-ms-interpolation-mode:bicubic; }
p { display:block;margin:13px 0; }</style><!--[if mso]>
<xml>
<o:OfficeDocumentSettings>
<o:AllowPNG/>
<o:PixelsPerInch>96</o:PixelsPerInch>
</o:OfficeDocumentSettings>
</xml>
<![endif]--><!--[if lte mso 11]>
<style type="text/css">
.mj-outlook-group-fix { width:100% !important; }
</style>
<![endif]--><!--[if !mso]><!--><link href="https://fonts.googleapis.com/css?family=Ubuntu:300,400,500,700" rel="stylesheet" type="text/css"><style type="text/css">@import url(https://fonts.googleapis.com/css?family=Ubuntu:300,400,500,700);</style><!--<![endif]--><style type="text/css">@media only screen and (min-width:480px) {
.mj-column-per-100 { width:100% !important; max-width: 100%; }
.mj-column-per-50 { width:50% !important; max-width: 50%; }
}</style><style type="text/css"></style><!-- mj-include fails to read file : _header.mjml at /home/ndjs/mjml-website-b3148cc8-1191/_header.mjml --></head><body><div style="display:none;font-size:1px;color:#ffffff;line-height:1px;max-height:0px;max-width:0px;opacity:0;overflow:hidden;">[% i18n("Certificate") %]</div><div><!--[if mso | IE]><table align="center" border="0" cellpadding="0" cellspacing="0" class="" style="width:600px;" width="600" ><tr><td style="line-height:0px;font-size:0px;mso-line-height-rule:exactly;"><![endif]--><div style="margin:0px auto;max-width:600px;"><table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="width:100%;"><tbody><tr><td style="direction:ltr;font-size:0px;padding:20px 0;text-align:center;"><!--[if mso | IE]><table role="presentation" border="0" cellpadding="0" cellspacing="0"><tr></tr></table><![endif]--></td></tr></tbody></table></div><!--[if mso | IE]></td></tr></table><table align="center" border="0" cellpadding="0" cellspacing="0" class="" style="width:600px;" width="600" ><tr><td style="line-height:0px;font-size:0px;mso-line-height-rule:exactly;"><![endif]--><div style="margin:0px auto;max-width:600px;"><table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="width:100%;"><tbody><tr><td style="direction:ltr;font-size:0px;padding:20px 0;text-align:center;"><!--[if mso | IE]><table role="presentation" border="0" cellpadding="0" cellspacing="0"><tr><td class="" width="600px" ><table align="center" border="0" cellpadding="0" cellspacing="0" class="" style="width:600px;" width="600" ><tr><td style="line-height:0px;font-size:0px;mso-line-height-rule:exactly;"><![endif]--><div style="margin:0px auto;max-width:600px;"><table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="width:100%;"><tbody><tr><td style="direction:ltr;font-size:0px;padding:20px 0;text-align:center;"><!--[if mso | IE]><table role="presentation" border="0" cellpadding="0" cellspacing="0"><tr><td class="" style="vertical-align:top;width:600px;" ><![endif]--><div class="mj-column-per-100 mj-outlook-group-fix" style="font-size:0px;text-align:left;direction:ltr;display:inline-block;vertical-align:top;width:100%;"><table border="0" cellpadding="0" cellspacing="0" role="presentation" style="vertical-align:top;" width="100%"><tr><td align="left" style="font-size:0px;padding:10px 25px;word-break:break-word;"><div style="font-family:Ubuntu, Helvetica, Arial, sans-serif;font-size:13px;line-height:1;text-align:left;color:#000000;">[% i18n("Certificate") %]</div></td></tr></table></div><!--[if mso | IE]></td></tr></table><![endif]--></td></tr></tbody></table></div><!--[if mso | IE]></td></tr></table></td></tr><tr><td class="" width="600px" ><table align="center" border="0" cellpadding="0" cellspacing="0" class="" style="width:600px;" width="600" ><tr><td style="line-height:0px;font-size:0px;mso-line-height-rule:exactly;"><![endif]--><div style="margin:0px auto;max-width:600px;"><table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="width:100%;"><tbody><tr><td style="direction:ltr;font-size:0px;padding:20px 0;text-align:center;"><!--[if mso | IE]><table role="presentation" border="0" cellpadding="0" cellspacing="0"><tr><td class="" style="vertical-align:top;width:600px;" ><![endif]--><div class="mj-column-per-100 mj-outlook-group-fix" style="font-size:0px;text-align:left;direction:ltr;display:inline-block;vertical-align:top;width:100%;"><table border="0" cellpadding="0" cellspacing="0" role="presentation" style="vertical-align:top;" width="100%"><tr><td style="font-size:0px;padding:10px 25px;word-break:break-word;"><p style="border-top:solid 4px #000000;font-size:1;margin:0px auto;width:100%;"></p><!--[if mso | IE]><table align="center" border="0" cellpadding="0" cellspacing="0" style="border-top:solid 4px #000000;font-size:1;margin:0px auto;width:550px;" role="presentation" width="550px" ><tr><td style="height:0;line-height:0;"> &nbsp;
</td></tr></table><![endif]--></td></tr></table></div><!--[if mso | IE]></td></tr></table><![endif]--></td></tr></tbody></table></div><!--[if mso | IE]></td></tr></table></td></tr><tr><td class="" width="600px" ><table align="center" border="0" cellpadding="0" cellspacing="0" class="" style="width:600px;" width="600" ><tr><td style="line-height:0px;font-size:0px;mso-line-height-rule:exactly;"><![endif]--><div style="margin:0px auto;max-width:600px;"><table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="width:100%;"><tbody><tr><td style="direction:ltr;font-size:0px;padding:20px 0;padding-top:0;text-align:center;"><!--[if mso | IE]><table role="presentation" border="0" cellpadding="0" cellspacing="0"><tr><td class="" style="vertical-align:top;width:600px;" ><![endif]--><div class="mj-column-per-100 mj-outlook-group-fix" style="font-size:0px;text-align:left;direction:ltr;display:inline-block;vertical-align:top;width:100%;"><table border="0" cellpadding="0" cellspacing="0" role="presentation" style="vertical-align:top;" width="100%"><tr><td align="left" style="font-size:0px;padding:10px 25px;word-break:break-word;"><div style="font-family:Ubuntu, Helvetica, Arial, sans-serif;font-size:13px;line-height:1;text-align:left;color:#000000;"><p style="padding-bottom: 20px">[% i18n("Hello") %]</p><p>{{.P12MailHeader}}</p></div></td></tr></table></div><!--[if mso | IE]></td></tr></table><![endif]--></td></tr></tbody></table></div><!--[if mso | IE]></td></tr></table></td></tr><tr><td class="" width="600px" ><table align="center" border="0" cellpadding="0" cellspacing="0" class="" style="width:600px;" width="600" ><tr><td style="line-height:0px;font-size:0px;mso-line-height-rule:exactly;"><![endif]--><div style="margin:0px auto;max-width:600px;"><table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="width:100%;"><tbody><tr><td style="direction:ltr;font-size:0px;padding:20px 0;padding-top:0;text-align:center;"><!--[if mso | IE]><table role="presentation" border="0" cellpadding="0" cellspacing="0"><tr><td class="" style="vertical-align:top;width:300px;" ><![endif]--><div class="mj-column-per-50 mj-outlook-group-fix" style="font-size:0px;text-align:left;direction:ltr;display:inline-block;vertical-align:top;width:100%;"><table border="0" cellpadding="0" cellspacing="0" role="presentation" style="vertical-align:top;" width="100%"><tr><td align="left" style="font-size:0px;padding:10px 25px;word-break:break-word;"><div style="font-family:Ubuntu, Helvetica, Arial, sans-serif;font-size:13px;line-height:1;text-align:left;color:#000000;"><p class="label">Password: {{.password}} %]</p></div></td></tr></table></div><!--[if mso | IE]></td></tr></table><![endif]--></td></tr></tbody></table></div><!--[if mso | IE]></td></tr></table></td></tr><tr><td class="" width="600px" ><table align="center" border="0" cellpadding="0" cellspacing="0" class="" style="width:600px;" width="600" ><tr><td style="line-height:0px;font-size:0px;mso-line-height-rule:exactly;"><![endif]--><div style="margin:0px auto;max-width:600px;"><table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="width:100%;"><tbody><tr><td style="direction:ltr;font-size:0px;padding:20px 0;padding-top:0;text-align:center;"><!--[if mso | IE]><table role="presentation" border="0" cellpadding="0" cellspacing="0"><tr><td class="" style="vertical-align:top;width:600px;" ><![endif]--><div class="mj-column-per-100 mj-outlook-group-fix" style="font-size:0px;text-align:left;direction:ltr;display:inline-block;vertical-align:top;width:100%;"><table border="0" cellpadding="0" cellspacing="0" role="presentation" style="vertical-align:top;" width="100%"><tr><td align="left" style="font-size:0px;padding:10px 25px;word-break:break-word;"><div style="font-family:Ubuntu, Helvetica, Arial, sans-serif;font-size:13px;line-height:1;text-align:left;color:#000000;"><p style="padding-bottom: 20px">[% i18n("Hello") %]</p><p>{{.P12MailFooter}}</p></div></td></tr></table></div><!--[if mso | IE]></td></tr></table><![endif]--></td></tr></tbody></table></div><!--[if mso | IE]></td></tr></table></td></tr></table><![endif]--></td></tr></tbody></table></div><!--[if mso | IE]></td></tr></table><![endif]--><!-- mj-include fails to read file : _footer.mjml at /home/ndjs/mjml-website-b3148cc8-1191/_footer.mjml --></div></body></html>`

func (h Handler) email(cert Cert, profile Profile, file []byte, password string) (Info, error) {
	pfconfigdriver.PfconfigPool.AddStruct(h.Ctx, &pfconfigdriver.Config.PfConf.Alerting)

	alerting := pfconfigdriver.Config.PfConf.Alerting

	Information := Info{}
	m := gomail.NewMessage()
	m.SetHeader("From", alerting.FromAddr)
	m.SetHeader("To", cert.Mail)
	m.SetHeader("Subject", profile.P12MailSubject)

	var w io.Writer

	email := Email{Header: profile.P12MailHeader, Footer: profile.P12MailFooter}

	if profile.P12MailPassword == 1 {
		email.Password = password
		Information.Password = password
	}

	t := template.New("Email")
	t, _ = t.Parse(emailTemplate)
	t.Execute(w, &profile)

	m.SetBody("text/html", fmt.Sprint(w))

	m.Attach(cert.Cn+".p12", gomail.SetCopyFunc(func(w io.Writer) error {
		_, err := w.Write(file)
		return err
	}))

	SMTPPort, err := strconv.Atoi(alerting.SMTPPort)

	if err != nil {
		Information.Error = "Wrong port number"
		return Information, err
	}

	d := gomail.NewDialer(alerting.SMTPServer, SMTPPort, alerting.SMTPUsername, alerting.SMTPPassword)

	if alerting.SMTPVerifySSL == "disabled" {
		d.TLSConfig = &tls.Config{InsecureSkipVerify: true}
	}

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
