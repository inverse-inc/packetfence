package pfpki

import (
	"bytes"
	"crypto/tls"
	"fmt"
	"html/template"
	"io"
	"io/ioutil"
	"strings"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"golang.org/x/text/language"
	"golang.org/x/text/message"
	"golang.org/x/text/message/catalog"
	gomail "gopkg.in/gomail.v2"
	yaml "gopkg.in/yaml.v2"
)

// Email strucure
type Email struct {
	Header   string
	Footer   string
	Password string
}

func (h Handler) email(cert Cert, profile Profile, file []byte, password string) (Info, error) {
	pfconfigdriver.PfconfigPool.AddStruct(h.Ctx, &pfconfigdriver.Config.PfConf.Alerting)
	pfconfigdriver.PfconfigPool.AddStruct(h.Ctx, &pfconfigdriver.Config.PfConf.Advanced)
	alerting := pfconfigdriver.Config.PfConf.Alerting
	advanced := pfconfigdriver.Config.PfConf.Advanced

	Information := Info{}

	dict, err := parseYAMLDict()
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	cat, err := catalog.NewFromMap(dict)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	message.DefaultCatalog = cat

	m := gomail.NewMessage()
	m.SetHeader("From", alerting.FromAddr)
	m.SetHeader("To", cert.Mail)
	m.SetHeader("Subject", profile.P12MailSubject)

	email := Email{Header: profile.P12MailHeader, Footer: profile.P12MailFooter}

	// Undefined Header
	if profile.P12MailHeader == "" {
		email.Header = "msg_header"
	}
	// Undefined Footer
	if profile.P12MailHeader == "" {
		email.Footer = "msg_footer"
	}

	if profile.P12MailPassword == 1 {
		email.Password = password
		Information.Password = password
	}

	lang := language.MustParse(advanced.Language)

	emailContent, err := parseTemplate("emails-pki_certificate.html", lang, email)

	m.SetBody("text/html", emailContent)

	m.Attach(cert.Cn+".p12", gomail.SetCopyFunc(func(w io.Writer) error {
		_, err := w.Write(file)
		return err
	}))

	d := gomail.NewDialer(alerting.SMTPServer, alerting.SMTPPort, alerting.SMTPUsername, alerting.SMTPPassword)

	if alerting.SMTPVerifySSL == "disabled" {
		d.TLSConfig = &tls.Config{InsecureSkipVerify: true}
	}

	if err := d.DialAndSend(m); err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	return Information, nil
}

func parseTemplate(tplName string, lang language.Tag, data interface{}) (string, error) {
	p := message.NewPrinter(lang)
	fmap := template.FuncMap{
		"translate": p.Sprintf,
	}

	t, err := template.New(tplName).Funcs(fmap).ParseFiles("/usr/local/pf/html/captive-portal/templates/emails/" + tplName)
	if err != nil {
		return "", fmt.Errorf("cannot parse template")
	}

	buf := bytes.NewBuffer([]byte{})
	if err := t.Execute(buf, data); err != nil {
		return "", fmt.Errorf("cannot execute parse template")
	}

	return buf.String(), nil
}

func parseYAMLDict() (map[string]catalog.Dictionary, error) {
	dir := "/usr/local/pf/conf/caddy-services/locales"
	files, err := ioutil.ReadDir(dir)
	if err != nil {
		fmt.Println(err)
		return nil, err
	}

	translations := map[string]catalog.Dictionary{}

	for _, f := range files {
		yamlFile, err := ioutil.ReadFile(dir + "/" + f.Name())
		if err != nil {
			return nil, err
		}
		data := map[string]string{}
		err = yaml.Unmarshal(yamlFile, &data)
		if err != nil {
			return nil, err
		}

		lang := strings.Split(f.Name(), ".")[0]

		translations[lang] = &dictionary{Data: data}
	}

	return translations, nil
}

type dictionary struct {
	Data map[string]string
}

func (d *dictionary) Lookup(key string) (data string, ok bool) {
	if _, ok := d.Data[key]; !ok {
		return "", false
	}

	return "\x02" + d.Data[key], true
}
