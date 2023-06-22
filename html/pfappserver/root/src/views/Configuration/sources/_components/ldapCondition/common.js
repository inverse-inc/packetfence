export const parseLdapStringToArray = (ldapString) => {
  const ldapArrayRegex = new RegExp('^[[(]')
  if (ldapArrayRegex.test(ldapString)) {
    return ldapString.split(' ')
      .filter((item) => !['[', ']', '(', ')'].includes(item))
  } else {
    return [ldapString]
  }
}
