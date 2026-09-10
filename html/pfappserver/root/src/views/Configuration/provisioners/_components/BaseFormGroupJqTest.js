import { BaseFormGroupTextareaTest, BaseFormGroupTextareaTestProps } from '@/components/new/'
import store from '@/store'
import i18n from '@/utils/locale'

// The feedback of the test is rendered with `v-html`, so anything coming from
// the sample payload or from the API must be escaped: both are attacker
// influenceable and would otherwise run in the admin's own session.
const escapeHtml = value => String(value).replace(/[&<>"']/g, character => ({
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#39;'
}[character]))

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
        html.push(`<strong>${escapeHtml(passes ? i18n.t('Passes') : i18n.t('Does not pass'))}</strong><br/>`)
        html.push(`${escapeHtml(i18n.t('Results'))}: <code>${escapeHtml(JSON.stringify(results))}</code>`)
        html.push('</pre>')
        return html.join('')
      }).catch(err => {
        const { response: { data: { message = i18n.t('Unknown error') } = {} } = {} } = err
        throw `<pre style="color: inherit;">${escapeHtml(message)}</pre>`
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
