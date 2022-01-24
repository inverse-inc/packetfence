const Radius = require('radius')
const dgram = require('dgram')
const db = require('node-persist')

const codes = {
  access_request: 'Access-Request',
  access_reject: 'Access-Reject',
  access_accept: 'Access-Accept',
  accounting_response: 'Accounting-Response'
}

const mock = {}

mock.radius = function (host, port, secret, user_name, user_password) {

  this.host = host
  this.port = port
  this.secret = secret
  this.user_name = user_name
  this.user_password = user_password

  this.socket = dgram.createSocket('udp4')

  this.socket.on('error', err => {
    console.error(err)
    this.socket.close()
  })

  this.socket.on('listening', () => {
    const address = this.socket.address()
    console.info('RADIUS listening on ' + address.address + ':' + address.port)

    Promise.resolve(db.init()).then(() => {
      db.setItem('history', [])
    })
  })

  this.socket.on('message', (message, client) => {
    let response_code

    const request = Radius.decode({
        packet: message,
        secret: this.secret
    })
    const { code, identifer, length, attributes, attributes: {
      'Acct-Status-Type': _acct_status_type,
      'User-Name': _user_name,
      'User-Password': _user_password
    } } = request

    switch (code) {

      case 'Accounting-Request': // RFC2866 (4.2)
        response_code = codes.accounting_response
        break

      case 'Access-Request':
      default:
        if (this.user_name) {
          if (_user_name === this.user_name && _user_password === this.user_password) {
            response_code = codes.access_accept
          }
          else {
            response_code = codes.access_reject
          }
        }
        else {
          response_code = codes.access_accept
        }
        break

    }

    console.debug(`Sending ${response_code}: ${JSON.stringify({ code, identifer, length, attributes })}`)

    const response = Radius.encode_response({
        packet: request,
        code: response_code,
        secret: this.secret
    })

    Promise.resolve(db.init()).then(() => {
      db.getItem('history').then(history => {
        history.push({ code, identifer, length, attributes })
        db.setItem('history', history)
      })
    })

    this.socket.send(response, 0, response.length, client.port, client.address, err => {
      if (err) {
        console.error('Error sending reponse to ', client)
      }
    })
  })

  return this
}

mock.radius.prototype.bind = function () {
  try {
    return this.socket.bind(this.port, this.host)
  }
  catch {}
}

mock.radius.prototype.close = function () {
  console.info('RADIUS closing on ' + address.address + ':' + address.port)
  return this.socket.close()
}

module.exports = mock.radius