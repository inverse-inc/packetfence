import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'switchGroupIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'switchGroupIdNotExistsExcept',
    message: message || i18n.t('Switch Group exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getSwitchGroups').then(response => {
        return response.filter(switche => switche.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

import { schemaInlineTriggers } from '../switches/schema'

export const schema = (props) => {
  const {
    isNew,
    isClone,
    id,
  } = props

  return yup.object({
    id: yup.string()
      .nullable()
      .required(i18n.t('Identifier required.'))
      .switchGroupIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),

    inlineTrigger: schemaInlineTriggers.meta({ invalidFeedback: i18n.t('Inline conditions contains one or more errors.') })
  })
}

export default schema
