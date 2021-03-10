/**
 * MessageFormat Class - Custom formatting used with 'vue-i18n'
 *
 * https://messageformat.github.io/messageformat/MessageFormat
 *
**/
import MessageFormat from 'messageformat'

export default class CustomFormatter {
  constructor (options = {}) {
    // set locale
    this._locale = options.locale || 'en-US'
    // instanstantiate formatter
    this._formatter = new MessageFormat(this._locale)
    // initialize object cache
    this._caches = Object.create(null)
  }

  interpolate (message, values) {
    // reference cache
    let fn = this._caches[message]
    if (!fn) {
      // no cache, compile once
      fn = this._formatter.compile(message, this._locale)
      // cache
      this._caches[message] = fn
    }
    return [fn(values)]
  }
}
