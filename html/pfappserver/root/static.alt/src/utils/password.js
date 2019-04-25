const password = {
  generate (pwlength = 8, options = { upper: true, lower: true, digits: true, special: false, brackets: false, high: false, ambiguous: false }) {
    const charRanges = {
      upper: 'ABCDEFGHJKLMNPQRSTUVWXYZ',
      lower: 'abcdefghijkmnpqrstuvwxyz',
      digits: '123456789',
      special: '!@#$%^&*_+-=,./?;:`"~\'\\',
      brackets: '(){}[]<>',
      high: '¡¢£¤¥¦§©ª«¬®¯°±²³´µ¶¹º»¼½¾¿ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþ',
      ambiguous: 'O0oIl'
    }
    const ranges = Object.keys(charRanges).filter(range => options[range]).map(range => charRanges[range])
    if (!ranges.length) return
    const charset = ranges.join('')
    let randomPassword = ''
    for (var i = 0, n = charset.length; i < pwlength; ++i) {
      randomPassword += charset.charAt(Math.floor(Math.random() * n))
    }
    return randomPassword
  }
}

export default password
