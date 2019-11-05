package pfpki

import (
	"crypto/tls"
	"io"

	"gopkg.in/gomail.v2"
)

func email(cert Cert, profile Profile, file []byte) error {

	m := gomail.NewMessage()
	m.SetHeader("From", profile.P12MailFrom)
	m.SetHeader("To", cert.Mail)
	m.SetHeader("Subject", profile.P12MailSubject)

	m.Attach("cert.p12", gomail.SetCopyFunc(func(w io.Writer) error {
		_, err := w.Write(file)
		return err
	}))

	d := gomail.NewDialer(profile.P12SmtpServer, 25, "user", "123456")
	d.TLSConfig = &tls.Config{InsecureSkipVerify: true}

	if err := d.DialAndSend(m); err != nil {
		return err
	}

	return nil
}
