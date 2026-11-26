import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'maintenanceTaskIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'maintenanceTaskIdNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getMaintenanceTasks').then(response => {
        return response.filter(maintenanceTask => maintenanceTask.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

// SaaS: node_meta billing rows carry the live monthly billing cycle,
// the backend refuses a window under 60 days (2 months).
const saasBillingMinWindowTasks = ['node_meta_billing_retention']

export default (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Name required.'))
      .maintenanceTaskIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),
    ...((store.getters['system/isSaas'] && saasBillingMinWindowTasks.includes(id))
      ? { window: yup.object().nullable().minDuration(60, 'D', i18n.t('Minimum 60 days.')) }
      : {}
    )
  })
}

export { yup }
