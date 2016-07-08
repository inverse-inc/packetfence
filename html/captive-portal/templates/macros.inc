[%# Insert an SVG element from sprite.svg %]
[% MACRO svgIcon BLOCK %]
<svg class="iconic[% IF size %] iconic--[% size %][% END %]" viewBox="0 0 100 100">
  <g class="iconic__hide">
    <use xlink:href="#[% id %]"></use>
  </g>
  <image class="iconic[% IF size %] iconic--[% size %][% END %]" src="/common/img/[% id %].png" xlink:href=""/>
</svg>
[% END %]

[%# Select the appropriate SVG icon for the specified billing engine %]
[% MACRO flashIcon BLOCK;
 SWITCH level.lower;
   CASE 'error';
     svgIcon(id='ic_error_black_24px',size='small');
   # Default
   CASE;
     svgIcon(id='ic_warning_black_24px',size='small');
 END;
END %]

[%# Select the appropriate SVG icon for the specified authentication module %]
[% MACRO moduleIcon BLOCK;
 # See modules under lib/captiveportal/PacketFence/DynamicRouting/Module/Authentication
 SWITCH module.lower;
   CASE 'module-authentication-billing';
     svgIcon(id='ic_credit_card_black_24px',size=size);
   CASE 'module-authentication-choice';
     svgIcon(id='ic_more_horiz_black_24px',size=size);
   CASE 'module-authentication-email';
     svgIcon(id='ic_email_black_24px',size=size);
   CASE 'module-authentication-login';
     svgIcon(id='ic_vpn_key_black_24px',size=size);
   CASE 'module-authentication-null';
     svgIcon(id='ic_forward_black_24px',size=size);
   CASE 'module-authentication-saml';
     svgIcon(id='ic_cloud_circle_black_24px',size=size);
   CASE 'module-authentication-sms';
     svgIcon(id='ic_textsms_black_24px',size=size);
   CASE 'module-authentication-sponsor';
     svgIcon(id='ic_supervisor_account_black_24px',size=size);
   # OAuth modules
   CASE ['module-authentication-oauth-facebook', 'facebook'];
     svgIcon(id='facebook-icon',size=size);
   CASE ['module-authentication-oauth-github', 'github'];
     svgIcon(id='github-icon',size=size);
   CASE ['module-authentication-oauth-google', 'google'];
     svgIcon(id='google-icon',size=size);
   CASE ['module-authentication-oauth-instagram', 'instagram'];
     svgIcon(id='instagram-icon',size=size);
   CASE ['module-authentication-oauth-linkedin', 'linkedin'];
     svgIcon(id='linkedin-icon',size=size);
   CASE ['module-authentication-oauth-pinterest', 'pinterest'];
     svgIcon(id='linkedin-icon',size=size);
   CASE ['module-authentication-oauth-twitter', 'twitter'];
     svgIcon(id='twitter-icon',size=size);
   CASE ['module-authentication-oauth-windowslive', 'windowslive'];
     svgIcon(id='outlook-icon',size=size);
   # Default
   CASE;
     svgIcon(id='ic_security_black_24px',size=size);
     #svgIcon(id='ic_lock_black_24px',size=size);
 END;
END %]

[%# Select the appropriate SVG icon for the specified billing engine %]
[% MACRO billingIcon BLOCK;
 SWITCH billing.lower;
   CASE 'paypal';
     svgIcon(id='paypal-icon',size=size);
   CASE 'stripe';
     svgIcon(id='stripe-icon',size=size);
   # Default
   CASE;
     svgIcon(id='ic_credit_card_black_24px',size=size);
 END;
END %]
