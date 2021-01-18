import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'wrixLocationIdNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'wrixLocationIdNotExistsExcept',
    message: message || i18n.t('Identifier exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getWrixLocations').then(response => {
        return response.filter(wrixLocation => wrixLocation.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

export default (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Identifier required.'))
      .wrixLocationIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),
    Provider_Identifier: yup.string().nullable().required().max(255, i18n.t('Maximum 255 characters.')),
    Location_Identifier: yup.string().nullable().required().max(255, i18n.t('Maximum 255 characters.')),
    Service_Provider_Brand: yup.string().nullable().required().max(255, i18n.t('Maximum 255 characters.')),
    Location_Type: yup.string().nullable().required().max(255, i18n.t('Maximum 255 characters.')),
    Sub_Location_Type: yup.string().nullable().required().max(255, i18n.t('Maximum 255 characters.')),
    English_Location_Name: yup.string().nullable().required().max(255, i18n.t('Maximum 255 characters.')),
    Location_Address1: yup.string().nullable().required().max(255, i18n.t('Maximum 255 characters.')),
    Location_Address2: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    English_Location_City: yup.string().nullable().required().max(255, i18n.t('Maximum 255 characters.')),
    Location_Zip_Postal_Code: yup.string().nullable().required().max(255, i18n.t('Maximum 255 characters.')),
    Location_State_Province_Name: yup.string().nullable().required().max(255, i18n.t('Maximum 255 characters.')),
    Location_Country_Name: yup.string().nullable().required().max(255, i18n.t('Maximum 255 characters.')),
    Location_Phone_Number: yup.string().nullable().required().max(255, i18n.t('Maximum 255 characters.')),
    Location_URL: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    Coverage_Area: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    SSID_Open_Auth: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    WEP_Key: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    WEP_Key_Entry_Method: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    WEP_Key_Size: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    SSID_1X: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    Client_Support: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    MAC_Address: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    Open_Monday: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    Open_Tuesday: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    Open_Wednesday: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    Open_Thursday: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    Open_Friday: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    Open_Saturday: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    Open_Sunday: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    Longitude: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.')),
    Latitude: yup.string().nullable().max(255, i18n.t('Maximum 255 characters.'))
  })
}
