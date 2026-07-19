import { BaseFormGroupTextareaTest, BaseFormGroupTextareaTestProps } from '@/components/new/'
import store from '@/store'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupTextareaTestProps,

  test: {
    type: Function,
    default: (value, form) => {
      const { jq_query } = form
      return store.dispatch('$_provisionings/testJq', { jq_query, json: value }).then(response => {
        const { passes, results } = response
        let html = []
        html.push('<pre style="color: inherit;">')
        html.push(`<strong>${passes ? i18n.t('Passes') : i18n.t('Does not pass')}</strong><br/>`)
        html.push(`${i18n.t('Results')}: <code>${JSON.stringify(results)}</code>`)
        html.push('</pre>')
        return html.join('')
      }).catch(err => {
        const { response: { data: { message = i18n.t('Unknown error') } = {} } = {} } = err
        throw `<pre style="color: inherit;">${message}</pre>`
      })
    }
  },
  testLabel: {
    type: String,
    default: i18n.t('Testing...')
  }
}

export default {
  name: 'base-form-group-jq-test',
  extends: BaseFormGroupTextareaTest,
  props
}
