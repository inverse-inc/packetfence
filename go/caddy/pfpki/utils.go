package pfpki

import (
	"crypto/tls"
	"io"

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
