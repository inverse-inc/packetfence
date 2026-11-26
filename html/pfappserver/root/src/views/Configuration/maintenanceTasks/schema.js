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

// SaaS: the monthly device counts are read from these tables once the month is over,
//  the backend refuses a window under this minimum
export const saasMinWindowDays = 32
export const saasMinWindowTasks = ['auth_log_cleanup', 'radius_audit_log_cleanup']
export const isSaasMinWindowTask = id => store.getters['system/isSaas'] && saasMinWindowTasks.includes(id)

// same units as the backend (pf::util::normalize_time)
const unitSeconds = { s: 1, m: 60, h: 3600, D: 86400, W: 7 * 86400, M: 30 * 86400, Y: 365 * 86400 }

const schemaSaasMinWindow = yup.object({
  interval: yup.string().nullable()
    .test('saasMinWindow', i18n.t('Minimum {days} days.', { days: saasMinWindowDays }), function (interval) {
      const { unit } = this.parent || {}
      if (!interval || !(unit in unitSeconds)) return true
      return +interval * unitSeconds[unit] >= saasMinWindowDays * unitSeconds.D
    }),
  unit: yup.string().nullable()
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
      .required(i18n.t('Name required.'))
      .maintenanceTaskIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),
    ...((isSaasMinWindowTask(id))
      ? { window: schemaSaasMinWindow }
      : {}
    )
  })
}

export { yup }
