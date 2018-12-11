import i18n from '@/utils/locale'
import {
  pfConfigurationListColumns,
  pfConfigurationListFields,
  pfConfigurationViewFields
} from '@/globals/pfConfiguration'

export const pfConfigurationAuthenticationSourcesListColumns = [
  Object.assign(pfConfigurationListColumns.id, { label: i18n.t('Name') }), // re-label
  pfConfigurationListColumns.description,
  pfConfigurationListColumns.class,
  pfConfigurationListColumns.type,
  pfConfigurationListColumns.buttons
]

export const pfConfigurationAuthenticationSourcesListFields = [
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('Name') }), // re-text
  pfConfigurationListFields.description,
  pfConfigurationListFields.class,
  pfConfigurationListFields.type
]

export const pfConfigurationAuthenticationSourceViewFields = (context) => {
  const { sourceType = null } = context
  switch (sourceType) {
    case 'AD':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.host_port_encryption,
        pfConfigurationViewFields.connection_timeout,
        pfConfigurationViewFields.write_timeout,
        pfConfigurationViewFields.read_timeout,
        pfConfigurationViewFields.basedn,
        pfConfigurationViewFields.scope,
        pfConfigurationViewFields.usernameattribute,
        pfConfigurationViewFields.email_attribute,
        pfConfigurationViewFields.binddn,
        pfConfigurationViewFields.password(context),
        pfConfigurationViewFields.cache_match,
        pfConfigurationViewFields.monitor,
        pfConfigurationViewFields.shuffle,
        pfConfigurationViewFields.realms(context),
        pfConfigurationViewFields.authentication_rules(context),
        pfConfigurationViewFields.administration_rules(context)
      ]
    case 'EAPTLS':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.realms(context),
        pfConfigurationViewFields.authentication_rules(context),
        pfConfigurationViewFields.administration_rules(context)
      ]
    case 'Htpasswd':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.path,
        pfConfigurationViewFields.realms(context),
        pfConfigurationViewFields.authentication_rules(context),
        pfConfigurationViewFields.administration_rules(context)
      ]
    case 'HTTP':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.protocol_ip_port,
        pfConfigurationViewFields.api_username,
        pfConfigurationViewFields.api_password,
        pfConfigurationViewFields.authentication_url,
        pfConfigurationViewFields.authorization_url,
        pfConfigurationViewFields.realms(context)
      ]
    case 'Kerberos':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.host,
        pfConfigurationViewFields.authenticate_realm,
        pfConfigurationViewFields.realms(context),
        pfConfigurationViewFields.authentication_rules(context),
        pfConfigurationViewFields.administration_rules(context)
      ]
    case 'LDAP':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.host_port_encryption,
        pfConfigurationViewFields.connection_timeout,
        pfConfigurationViewFields.write_timeout,
        pfConfigurationViewFields.read_timeout,
        pfConfigurationViewFields.basedn,
        pfConfigurationViewFields.scope,
        pfConfigurationViewFields.usernameattribute,
        pfConfigurationViewFields.email_attribute,
        pfConfigurationViewFields.binddn,
        pfConfigurationViewFields.password(context),
        pfConfigurationViewFields.cache_match,
        pfConfigurationViewFields.monitor,
        pfConfigurationViewFields.shuffle,
        pfConfigurationViewFields.realms(context),
        pfConfigurationViewFields.authentication_rules(context),
        pfConfigurationViewFields.administration_rules(context)
      ]
    case 'POTD':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.password_rotation,
        pfConfigurationViewFields.password_email_update,
        pfConfigurationViewFields.password_length,
        pfConfigurationViewFields.realms(context),
        pfConfigurationViewFields.authentication_rules(context),
        pfConfigurationViewFields.administration_rules(context)
      ]
    case 'RADIUS':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.host,
        pfConfigurationViewFields.secret,
        pfConfigurationViewFields.timeout,
        pfConfigurationViewFields.monitor,
        pfConfigurationViewFields.realms(context),
        pfConfigurationViewFields.authentication_rules(context),
        pfConfigurationViewFields.administration_rules(context)
      ]
    case 'SAML':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.sp_entity_id,
        pfConfigurationViewFields.sp_key_path,
        pfConfigurationViewFields.idp_entity_id,
        pfConfigurationViewFields.idp_metadata_path,
        pfConfigurationViewFields.idp_cert_path,
        pfConfigurationViewFields.idp_ca_cert_path,
        pfConfigurationViewFields.username_attribute,
        pfConfigurationViewFields.authorization_source_id(context)
      ]
    case 'Email':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        Object.assign(pfConfigurationViewFields.email_activation_timeout, {
          text: i18n.t('This is the delay given to a guest who registered by email confirmation to log into his email and click the activation link.')
        }), // re-text
        pfConfigurationViewFields.allow_localdomain,
        pfConfigurationViewFields.activation_domain,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Facebook':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('Graph API URL') }), // re-label
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('Graph API Token Path') }), // re-label
        pfConfigurationViewFields.access_token_param,
        pfConfigurationViewFields.access_scope,
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('Graph API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Github':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('API URL') }), // re-label
        pfConfigurationViewFields.authorize_path,
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('API Token Path') }), // re-label
        pfConfigurationViewFields.access_token_param,
        pfConfigurationViewFields.access_scope,
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Google':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('API URL') }), // re-label
        pfConfigurationViewFields.authorize_path,
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('API Token Path') }), // re-label
        pfConfigurationViewFields.access_token_param,
        pfConfigurationViewFields.access_scope,
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Instagram':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('Graph API URL') }), // re-label
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('Graph API Token Path') }), // re-label
        pfConfigurationViewFields.access_token_param,
        pfConfigurationViewFields.access_scope,
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('Graph API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Kickbox':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.api_key,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'LinkedIn':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('API URL') }), // re-label
        pfConfigurationViewFields.authorize_path,
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('API Token Path') }), // re-label
        pfConfigurationViewFields.access_token_param,
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Null':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.email_required,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'OpenID':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('API URL') }), // re-label
        pfConfigurationViewFields.authorize_path,
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('API Token Path') }), // re-label
        pfConfigurationViewFields.access_scope,
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Pinterest':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('Graph API URL') }), // re-label
        pfConfigurationViewFields.authorize_path,
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('Graph API Token Path') }), // re-label
        pfConfigurationViewFields.access_token_param,
        pfConfigurationViewFields.access_scope,
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'SMS':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.sms_carriers,
        pfConfigurationViewFields.sms_activation_timeout,
        pfConfigurationViewFields.message,
        pfConfigurationViewFields.pin_code_length,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'SponsorEmail':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.allow_localdomain,
        Object.assign(pfConfigurationViewFields.email_activation_timeout, { text: i18n.t('Delay given to a sponsor to click the activation link.') }), // re-text
        pfConfigurationViewFields.activation_domain,
        pfConfigurationViewFields.sponsorship_bcc,
        pfConfigurationViewFields.validate_sponsor,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Twilio':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.account_sid,
        pfConfigurationViewFields.auth_token,
        pfConfigurationViewFields.twilio_phone_number,
        pfConfigurationViewFields.message,
        pfConfigurationViewFields.pin_code_length,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Twitter':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('API URL') }), // re-label
        pfConfigurationViewFields.authorize_path,
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('API Token Path') }), // re-label
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'WindowsLive':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('API URL') }), // re-label
        pfConfigurationViewFields.authorize_path,
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('API Token Path') }), // re-label
        pfConfigurationViewFields.access_token_param,
        pfConfigurationViewFields.access_scope,
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'AdminProxy':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.proxy_addresses,
        pfConfigurationViewFields.user_header,
        pfConfigurationViewFields.group_header,
        pfConfigurationViewFields.administration_rules(context)
      ]
    case 'Blackhole':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description
      ]
    case 'Eduroam':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.server1_address,
        pfConfigurationViewFields.server1_port,
        pfConfigurationViewFields.server2_address,
        pfConfigurationViewFields.server2_port,
        pfConfigurationViewFields.radius_secret,
        pfConfigurationViewFields.auth_listening_port,
        pfConfigurationViewFields.reject_realm(context),
        pfConfigurationViewFields.local_realm(context),
        pfConfigurationViewFields.monitor,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'AuthorizeNet':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.api_login_id,
        pfConfigurationViewFields.transaction_key,
        pfConfigurationViewFields.public_client_key,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.currency,
        pfConfigurationViewFields.test_mode,
        pfConfigurationViewFields.send_email_confirmation,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins
      ]
    case 'Mirapay':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        { label: i18n.t('MiraPay iframe settings'), labelSize: 'lg' },
        pfConfigurationViewFields.base_url,
        pfConfigurationViewFields.merchant_id,
        pfConfigurationViewFields.shared_secret,
        { label: i18n.t('MiraPay direct settings'), labelSize: 'lg' },
        pfConfigurationViewFields.direct_base_url,
        pfConfigurationViewFields.terminal_id,
        pfConfigurationViewFields.shared_secret_direct,
        pfConfigurationViewFields.terminal_group_id,
        { label: i18n.t('Additional settings'), labelSize: 'lg' },
        pfConfigurationViewFields.service_fqdn,
        pfConfigurationViewFields.currency,
        pfConfigurationViewFields.test_mode,
        pfConfigurationViewFields.send_email_confirmation,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins
      ]
    case 'Paypal':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.currency,
        pfConfigurationViewFields.send_email_confirmation,
        pfConfigurationViewFields.test_mode,
        pfConfigurationViewFields.identity_token,
        pfConfigurationViewFields.cert_id,
        pfConfigurationViewFields.cert_file,
        pfConfigurationViewFields.key_file,
        pfConfigurationViewFields.paypal_cert_file,
        pfConfigurationViewFields.email_address,
        pfConfigurationViewFields.payment_type,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins
      ]
    case 'Stripe':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.currency,
        pfConfigurationViewFields.send_email_confirmation,
        pfConfigurationViewFields.test_mode,
        pfConfigurationViewFields.secret_key,
        pfConfigurationViewFields.publishable_key,
        pfConfigurationViewFields.style,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins
      ]
    default:
      return []
  }
}

export const pfConfigurationAuthenticationSourceViewDefaults = (context = {}) => {
  const { sourceType = null } = context
  switch (sourceType) {
    case 'AD':
      return {
        id: null,
        port: '389',
        encryption: 'none',
        connection_timeout: '1',
        write_timeout: '5',
        read_timeout: '10',
        scope: 'sub',
        usernameattribute: 'sAMAccountName',
        email_attribute: 'mail',
        cache_match: '1',
        authentication_rules: [],
        administration_rules: []
      }
    case 'HTTP':
      return {
        protocol: 'http',
        ip: '127.0.0.1',
        port: '10000'
      }
    case 'LDAP':
      return {
        id: null,
        port: '389',
        encryption: 'none',
        connection_timeout: '1',
        write_timeout: '5',
        read_timeout: '10',
        scope: 'sub',
        email_attribute: 'mail',
        monitor: '1'
      }
    case 'POTD':
      return {
        'password_rotation.interval': '10',
        'password_rotation.unit': 'm',
        password_length: '8'
      }
    case 'RADIUS':
      return {
        host: '127.0.0.1',
        port: '1812',
        timeout: '1'
      }
    case 'SAML':
      return {
        username_attribute: 'urn:oid:0.9.2342.19200300.100.1.1',
        authorization_source_id: 'local'
      }
    case 'Email':
      return {
        'email_activation_timeout.interval': '10',
        'email_activation_timeout.unit': 'm',
        allow_localdomain: 'yes',
        local_account_logins: '0'
      }
    case 'Facebook':
      return {
        site: 'https://graph.facebook.com',
        access_token_path: '/oauth/access_token',
        access_token_param: 'access_token',
        scope: 'email',
        protected_resource_url: 'https://graph.facebook.com/me?fields=id,name,email,first_name,last_name',
        redirect_url: 'https://<hostname>/oauth2/callback',
        domains: '*.facebook.com,*.fbcdn.net,*.akamaihd.net,*.akamaiedge.net,*.edgekey.net,*.akamai.net',
        local_account_logins: '0'
      }
    case 'Github':
      return {
        site: 'https://github.com',
        authorize_path: '/login/oauth/authorize',
        access_token_path: '/login/oauth/access_token',
        access_token_param: 'access_token',
        scope: 'user,user:email',
        protected_resource_url: 'https://api.github.com/user',
        redirect_url: 'https://<hostname>/oauth2/callback',
        domains: 'api.github.com,*.github.com,github.com',
        local_account_logins: '0'
      }
    case 'Google':
      return {
        client_id: 'YOUR_API_ID.apps.googleusercontent.com',
        site: 'https://accounts.google.com',
        authorize_path: '/o/oauth2/auth',
        access_token_path: '/o/oauth2/token',
        access_token_param: 'oauth_token',
        scope: 'https://www.googleapis.com/auth/userinfo.email',
        protected_resource_url: 'https://www.googleapis.com/oauth2/v2/userinfo',
        redirect_url: 'https://<hostname>/oauth2/callback',
        domains: '*.google.com,*.gstatic.com,googleapis.com,accounts.youtube.com,*.googleusercontent.com',
        local_account_logins: '0'
      }
    case 'Instagram':
      return {
        site: 'https://api.instagram.com',
        access_token_path: '/oauth/access_token',
        access_token_param: 'access_token',
        scope: 'basic',
        protected_resource_url: 'https://api.instagram.com/v1/users/self/?access_token=',
        redirect_url: 'https://<hostname>/oauth2/callback',
        domains: '*.instagram.com,*.cdninstagram.com,*.fbcdn.net',
        local_account_logins: '0'
      }
    case 'LinkedIn':
      return {
        site: 'https://www.linkedin.com',
        authorize_path: '/oauth/v2/authorization',
        access_token_path: '/oauth/v2/accessToken',
        access_token_param: 'code',
        protected_resource_url: 'https://api.linkedin.com/v1/people/~/email-address',
        redirect_url: 'https://<hostname>/oauth2/callback',
        domains: 'www.linkedin.com,api.linkedin.com,*.licdn.com,platform.linkedin.com',
        local_account_logins: '0'
      }
    case 'OpenID':
      return {
        scope: 'openid',
        redirect_url: 'https://<hostname>/oauth2/callback',
        local_account_logins: '0'
      }
    case 'Pinterest':
      return {
        site: 'https://api.pinterest.com',
        authorize_path: '/oauth/',
        access_token_path: '/v1/oauth/token',
        access_token_param: 'access_token',
        scope: 'read_public',
        protected_resource_url: 'https://api.pinterest.com/v1/me',
        redirect_url: 'https://<hostname>/oauth2/callback',
        domains: '*.pinterest.com,*.api.pinterest.com,*.akamaiedge.net,*.pinimg.com,*.fastlylb.net',
        local_account_logins: '0'
      }
    case 'SMS':
      return {
        sms_carriers: ['100056', '100057', '100058', '100059', '100060', '100061', '100062', '100063', '100064', '100065', '100066', '100067', '100068', '100069', '100070', '100071', '100072', '100073', '100074', '100075', '100076', '100077', '100078', '100079', '100080', '100081', '100082', '100083', '100084', '100085', '100086', '100087', '100088', '100089', '100090', '100091', '100092', '100093', '100094', '100095', '100096', '100097', '100098', '100099', '100100', '100101', '100102', '100103', '100104', '100105', '100106', '100107', '100108', '100109', '100110', '100111', '100112', '100113', '100114', '100115', '100116', '100117', '100118', '100119', '100120', '100121', '100122', '100123', '100124', '100125', '100126', '100127'],
        'sms_activation_timeout.interval': '10',
        'sms_activation_timeout.unit': 'm',
        'message': 'PIN: $pin',
        pin_code_length: '6',
        local_account_logins: '0'
      }
    case 'SponsorEmail':
      return {
        allow_localdomain: 'yes',
        'email_activation_timeout.interval': '30',
        'email_activation_timeout.unit': 'm',
        validate_sponsor: 'yes',
        local_account_logins: '0'
      }
    case 'Twilio':
      return {
        pin_code_length: '6',
        local_account_logins: '0'
      }
    case 'Twitter':
      return {
        client_id: '<CONSUMER KEY>',
        site: 'https://api.twitter.com',
        authorize_path: '/oauth/authenticate',
        access_token_path: '/oauth/request_token',
        protected_resource_url: 'https://api.twitter.com/oauth/access_token',
        redirect_url: 'https://<hostname>/oauth2/callback',
        domains: '*.twitter.com,twitter.com,*.twimg.com,twimg.com'
      }
    case 'WindowsLive':
      return {
        site: 'https://login.live.com',
        authorize_path: '/oauth20_authorize.srf',
        access_token_path: '/oauth20_token.srf',
        access_token_param: 'oauth_token',
        scope: 'wl.basic,wl.emails',
        protected_resource_url: 'https://apis.live.net/v5.0/me',
        redirect_url: 'https://<hostname>/oauth2/callback',
        domains: 'login.live.com,auth.gfx.ms,account.live.com',
        local_account_logins: '0'
      }
    case 'Eduroam':
      return {
        server1_port: '1812',
        server2_port: '1812',
        auth_listening_port: '11812',
        monitor: '1'
      }
    case 'AuthorizeNet':
      return {
        domains: '*.authorize.net',
        currency: 'USD',
        local_account_logins: '0'
      }
    case 'Mirapay':
      return {
        base_url: 'https://staging.eigendev.com/MiraSecure/GetToken.php',
        direct_base_url: 'https://staging.eigendev.com/OFT/EigenOFT_d.php',
        service_fqdn: 'packetfence.satkunas.com', // TODO: build fqdn dynamically
        currency: 'USD',
        local_account_logins: '0'
      }
    case 'Paypal':
      return {
        currency: 'USD',
        payment_type: '_xclick',
        domains: '*.paypal.com,*.paypalobjects.com',
        local_account_logins: '0'
      }
    case 'Stripe':
      return {
        currency: 'USD',
        style: 'charge',
        domains: '*.stripe.com',
        local_account_logins: '0'
      }
    case 'EAPTLS':
    case 'Htpasswd':
    case 'Kerberos':
    case 'Null':
    case 'AdminProxy':
    case 'Blackhole':
    default:
      return {}
  }
}
