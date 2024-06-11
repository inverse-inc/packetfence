import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export default (props) => {
  const {
    form
  } = props

  const {
    email,
    password,
    token,
  } = form || {}

  return yup.object().shape({
    email: yup.string().nullable()
      .when('id', {
        is: () => token === "",
        then: yup.string().required(i18n.t('Email is required when token not specified.')).email(),
        otherwise: yup.string()
      }).label(i18n.t('Email for performing FleetDM API Call')),
    password: yup.string().nullable()
      .when('id', {
        is: () => token === "",
        then: yup.string().required(i18n.t('Password is required when token not specified.')).min(6),
        otherwise: yup.string()
      }).label(i18n.t('Password for performing FleetDM API Call')),
    token: yup.string().nullable()
      .when('id', {
        is: () => email === "" || password === "",
        then: yup.string().required(i18n.t('Token is required when email / password not specified.')).min(20),
        otherwise: yup.string()
      }).label(i18n.t('Permanent API token for performing FleetDM API Call')),
  })
}
