package pfpki

import (
	"encoding/base64"
	"fmt"
	"net"
	"net/smtp"
)

func email(cert Cert, profile Profile, file []byte) error {

	// tlsConfig := tls.Config{
	// 	ServerName:         profile.P12SmtpServer,
	// 	InsecureSkipVerify: true,
	// }
	delimeter := "**=zaymlimiter"
	// conn, connErr := tls.Dial("tcp", fmt.Sprintf("%s:%d", profile.P12SmtpServer, 25), &tlsConfig)
	conn, connErr := net.Dial("tcp", fmt.Sprintf("%s:%d", profile.P12SmtpServer, 25))
	if connErr != nil {
		return connErr
	}
	defer conn.Close()

	client, clientErr := smtp.NewClient(conn, profile.P12SmtpServer)
	if clientErr != nil {
		return clientErr
	}
	defer client.Close()

	// auth := smtp.PlainAuth("", emailAddr, password, serverAddr)

	// if err := client.Auth(auth); err != nil {
	// 	log.Panic(err)
	// }

	if err := client.Mail(profile.P12MailFrom); err != nil {
		return err
	}
	// log.Println("Set 'TO(s)'")
	// for _, to := range tos {
	if err := client.Rcpt(cert.Mail); err != nil {
		return err
	}
	// }

	writer, writerErr := client.Data()
	if writerErr != nil {
		return writerErr
	}

	//basic email headers
	sampleMsg := fmt.Sprintf("From: %s\r\n", profile.P12MailFrom)
	sampleMsg += fmt.Sprintf("To: %s\r\n", cert.Mail)
	// if len(cc) > 0 {
	// 	sampleMsg += fmt.Sprintf("Cc: %s\r\n", strings.Join(cc, ";"))
	// }
	sampleMsg += profile.P12MailSubject + "\r\n"

	sampleMsg += "MIME-Version: 1.0\r\n"
	sampleMsg += fmt.Sprintf("Content-Type: multipart/mixed; boundary=\"%s\"\r\n", delimeter)

	sampleMsg += fmt.Sprintf("\r\n--%s\r\n", delimeter)
	sampleMsg += "Content-Type: text/html; charset=\"utf-8\"\r\n"
	sampleMsg += "Content-Transfer-Encoding: 7bit\r\n"
	sampleMsg += fmt.Sprintf("\r\n%s", "<html><body><h1>"+profile.P12MailSubject+"</h1>"+
		"<p>"+profile.P12MailHeader+"</p></body></html>\r\n")

	sampleMsg += fmt.Sprintf("\r\n--%s\r\n", delimeter)
	sampleMsg += "Content-Type: text/plain; charset=\"utf-8\"\r\n"
	sampleMsg += "Content-Transfer-Encoding: base64\r\n"
	sampleMsg += "Content-Disposition: attachment;filename=\"certificate.p12\"\r\n"
	sampleMsg += "\r\n" + base64.StdEncoding.EncodeToString(file)

	if _, err := writer.Write([]byte(sampleMsg)); err != nil {
		return err
	}

	if closeErr := writer.Close(); closeErr != nil {
		return closeErr
	}

	client.Quit()
	return nil
}
