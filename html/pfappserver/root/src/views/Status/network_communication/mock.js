export const mac = (selected = []) => {
  if (selected.length > 0) {
    return selected[Math.floor(Math.random() * selected.length)]
  }
  let h = parseInt(Math.floor(Math.random() * 15), 10).toString(16)
  let hh = `${h}${h}`
  return `${hh}:${hh}:${hh}:${hh}:${hh}:${hh}`
  /*
   let mac = ''
  for (let i = 0; i < 6; i++) {
    if (i > 0)
      mac += ':'
    mac += parseInt(Math.floor(Math.random() * 255), 10).toString(16).padStart(2, '0')
  }
  return mac
  */
}

export const proto = (selected = []) => {
  if (selected.length > 0) {
    return selected[Math.floor(Math.random() * selected.length)]
  }
  switch (Math.floor(Math.random() * 4)) {
    case 0:
    case 1:
    case 2:
      return 'TCP'
      // break;
    default:
      return 'UDP'
  }
}

export const port = (selected = []) => {
  if (selected.length > 0) {
    return selected[Math.floor(Math.random() * selected.length)]
  }
  return Math.floor(Math.random() * 65536)
}

export const host = (selected = []) => {
  if (selected.length > 0) {
    return selected[Math.floor(Math.random() * selected.length)]
  }
  switch (Math.floor(Math.random() * 15)) {
    case 0: return 'google.com' // break
    case 1: return 'images.google.com' // break
    case 2: return 'drive.google.com' // break
    case 3: return 'updates.google.com' // break
    case 4: return 'docs.google.com' // break
    case 5: return 'photos.google.com' // break
    case 6: return 'cdn-1.photos.google.com' // break
    case 7: return 'cdn-2.photos.google.com' // break
    case 8: return 'samsung.com' // break
    case 9: return 'updates.samsung.com' // break
    case 10: return 'hp.com' // break
    case 11: return 'akamai.com' // break
    case 12: return 'mail.google.com' // break
    case 13: return 'mx-1.mail.google.com' // break
    case 14: return 'google.ca' // break
  }
}

export const device_class = (selected = []) => {
  if (selected.length > 0) {
    return selected[Math.floor(Math.random() * selected.length)]
  }
  return [
    'Windows',
    'Hardware Manufacturer',
    'VoIP Device',
    'Linux',
    'Linux OS',
    'Datacenter appliance',
    'Windows OS',
    'VoIP Phones/Adapters',
    'Routers and APs',
    'Operating System',
    'Macintosh',
    'Smartphones/PDAs/Tablets',
    'iOS',
    'Android OS',
    'Router, Access Point or Femtocell',
    'Internet of Things (IoT)',
    'Phone, Tablet or Wearable',
    'Mac OS X or macOS',
  ][Math.floor(Math.random() * 18)]
}
