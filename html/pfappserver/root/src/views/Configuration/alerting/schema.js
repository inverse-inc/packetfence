import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => {
  return yup.object({
    emailaddr: yup.string().nullable().label(i18n.t('Email'))
      .isEmailCsv(),
    fromaddr: yup.string().nullable().email(),
    smtpserver: yup.string().nullable().label(i18n.t('Server')),
    subjectprefix: yup.string().nullable().label(i18n.t('Prefix')),
    smtp_encryption: yup.string().nullable().label(i18n.t('Encryption')),
    smtp_port: yup.string().nullable().label(i18n.t('Port'))
      .isPort(),
    smtp_username: yup.string().nullable().label(i18n.t('Username')),
    smtp_password: yup.string().nullable().label(i18n.t('Password')),
    smtp_timeout: yup.string().nullable().label(i18n.t('Timeout')),
    test_emailaddr: yup.string().label(i18n.t('Email'))
      .isEmailCsv()
  })
}

export default schema
