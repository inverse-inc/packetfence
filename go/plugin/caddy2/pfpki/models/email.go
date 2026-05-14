package models

import (
	"bytes"
	"context"
	"crypto/tls"
	"fmt"
	"html/template"
	"io"
	"os"
	"strings"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"golang.org/x/text/language"
	"golang.org/x/text/message"
	"golang.org/x/text/message/catalog"
	gomail "gopkg.in/gomail.v2"
	yaml "gopkg.in/yaml.v2"
)

// EmailType strucure
type EmailType struct {
	Header   string
	Footer   string
	Password string
	To       string
	From     string
	Subject  string
	FileName string
	File     []byte
	Template string
}

func emailcert(ctx context.Context, cert Cert, profile Profile, file []byte, password string) (types.Info, error) {
	alerting := pfconfigdriver.GetType[pfconfigdriver.PfConfAlerting](ctx)

	mail := EmailType{Header: profile.P12MailHeader, Footer: profile.P12MailFooter}
	if len(profile.P12MailFrom) > 0 {
		mail.From = profile.P12MailFrom
	} else if len(alerting.FromAddr) > 0 {
		mail.From = alerting.FromAddr
	} else {
		name, _ := os.Hostname()
		mail.From = "root@" + name
	}
	mail.To = cert.Mail
	mail.Subject = profile.P12MailSubject
	mail.FileName = cert.Cn
	mail.Template = "emails-pki_certificate.html"
	mail.File = file
	mail.Password = password
	return email(ctx, mail)
}

func emailRenewal(ctx context.Context, cert Cert, profile Profile) (types.Info, error) {
	alerting := pfconfigdriver.GetType[pfconfigdriver.PfConfAlerting](ctx)

	mail := EmailType{}

	if len(profile.RenewalMailFrom) > 0 {
		mail.From = profile.RenewalMailFrom
	} else {
		mail.From = alerting.FromAddr
	}

	if len(cert.Mail) > 0 {
		mail.To = cert.Mail
	} else if len(profile.Mail) > 0 {
		mail.To = profile.Mail
	} else if len(alerting.EmailAddr) > 0 {
		mail.To = alerting.EmailAddr
	} else {
		name, _ := os.Hostname()
		mail.From = "root@" + name
	}
	mail.Subject = profile.RenewalMailSubject
	mail.FileName = "Profile Name: " + profile.Name + " Certificate CN: " + cert.Cn
	mail.Template = "emails-renewal_certificate.html"
	mail.Header = profile.RenewalMailHeader
	mail.Footer = profile.RenewalMailFooter

	return email(ctx, mail)
}

func email(ctx context.Context, email EmailType) (types.Info, error) {
	alerting := pfconfigdriver.GetType[pfconfigdriver.PfConfAlerting](ctx)
	advanced := pfconfigdriver.GetType[pfconfigdriver.PfConfAdvanced](ctx)

	Information := types.Info{}

	dict, err := ParseYAMLDict()
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

	m.SetHeader("From", email.From)
	m.SetHeader("To", email.To)
	m.SetHeader("Subject", email.Subject)

	lang := language.MustParse(advanced.Language)

	emailContent, err := parseTemplate(email.Template, lang, email)
	if err != nil {
		// Previously this error was swallowed, sending a message with the
		// .p12 attached but an empty HTML body (so the recipient could not
		// see the unlock password). Surface it instead.
		Information.Error = err.Error()
		return Information, err
	}

	// Always include a plain-text alternative that carries the password
	// directly. Some mail clients strip HTML, and we want the unlock code
	// to survive template breakage on the HTML side.
	if len(email.Password) > 0 {
		m.SetBody("text/plain", "Password: "+email.Password)
		m.AddAlternative("text/html", emailContent)
	} else {
		m.SetBody("text/html", emailContent)
	}
	if len(email.File) > 0 {
		m.Attach(email.FileName+".p12", gomail.SetCopyFunc(func(w io.Writer) error {
			_, err := w.Write(email.File)
			return err
		}))
	}
	d := gomail.NewDialer(alerting.SMTPServer, alerting.SMTPPort, alerting.SMTPUsername, alerting.SMTPPassword.String())

	if alerting.SMTPVerifySSL == "disabled" || alerting.SMTPEncryption == "none" {
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
		return "", err
	}

	buf := bytes.NewBuffer([]byte{})
	if err := t.Execute(buf, data); err != nil {
		return "", err
	}

	return buf.String(), nil
}

func ParseYAMLDict() (map[string]catalog.Dictionary, error) {
	dir := "/usr/local/pf/conf/caddy-services/locales"
	files, err := os.ReadDir(dir)
	if err != nil {
		fmt.Println(err)
		return nil, err
	}

	translations := map[string]catalog.Dictionary{}

	for _, f := range files {
		yamlFile, err := os.ReadFile(dir + "/" + f.Name())
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
