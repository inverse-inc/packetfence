import { BaseFormGroupTextareaTest, BaseFormGroupTextareaTestProps } from '@/components/new/'
import store from '@/store'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupTextareaTestProps,

  test: {
    type: Function,
    default: (value, form) => {
      const test = Object.assign({}, form, { lines: form.lines.split('\n') }) // split lines by '\n', dereference
      return store.dispatch('$_event_handlers/dryRunEventHandler', test).then(response => {
        let html = []
        html.push('<pre style="color: inherit;">')
        response.items.forEach((item, index) => {
          html.push(`<code>${i18n.t('Line')} ${index + 1}\t- <strong>${item.line}</strong></code><br/>`)
          if (item.matches.length > 0) {
            item.matches.forEach(match => {
              match.actions.forEach(action => {
                html.push(`\t- ${match.rule.name}: ${action.api_method}(${action.api_parameters.map(param => '\'' + param + '\'').join(', ')})<br/>`)
              })
            })
          } else {
            html.push(`\t- ${i18n.t('No Rules Matched')}<br/>`)
          }
        })
        html.push('</pre>')
        return html.join('')
      }).catch(err => {
        let html = []
        let { response: { data: { errors = [] } } } = err
        errors.forEach(error => {
          const { field } = error // translate field names
          switch (field) {
            case 'id': error.field = i18n.t('Detector'); break
            case 'path': error.field = i18n.t('Alert pipe'); break
            case 'rules': error.field = i18n.t('Rules'); break
          }
          html.push(i18n.t('<strong>Server Error "{field}"</strong>: {message}', error) + '<br/>')
        })
        html.sort((a, b) => a.localeCompare(b))
        throw ['<pre style="color: inherit;">', ...html, '</pre>'].join('')
      })
    }
  },
  testLabel: {
    type: String,
    default: i18n.t('Testing...')
  }
}

export default {
  name: 'base-form-group-test',
  extends: BaseFormGroupTextareaTest,
  props
}


