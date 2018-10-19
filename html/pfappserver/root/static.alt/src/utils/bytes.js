const bytes = {
  toHuman (bytes, precision = 2, abbreviate = false) {
    if (bytes === 0) return (bytes.toString() + ' ')
    const prefixes = [
      { abbr: '', suffix: '', multiplier: Math.pow(1024, 0) },
      { abbr: 'k', suffix: 'kilo', multiplier: Math.pow(1024, 1) },
      { abbr: 'M', suffix: 'mega', multiplier: Math.pow(1024, 2) },
      { abbr: 'G', suffix: 'giga', multiplier: Math.pow(1024, 3) },
      { abbr: 'T', suffix: 'tera', multiplier: Math.pow(1024, 4) },
      { abbr: 'P', suffix: 'peta', multiplier: Math.pow(1024, 5) },
      { abbr: 'X', suffix: 'exa', multiplier: Math.pow(1024, 6) },
      { abbr: 'Z', suffix: 'zetta', multiplier: Math.pow(1024, 7) },
      { abbr: 'Y', suffix: 'yotta', multiplier: Math.pow(1024, 8) }
    ]
    for (let i = 0; i < prefixes.length; i++) {
      let quotient = bytes / prefixes[i].multiplier
      if (quotient >= 1 && quotient < 1024) {
        let q = Number.parseFloat(quotient).toFixed(precision).replace(/\.0+$/, '')
        return q + ' ' + ((abbreviate) ? prefixes[i].abbr : prefixes[i].suffix)
      }
    }
    return (bytes.toString() + ' ')
  }
}

export default bytes
