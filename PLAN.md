# Password Recovery for Captive Portal - Implementation Plan

## Overview

Add unauthenticated password recovery to the captive portal, allowing users to reset their password via email without being logged in.

## Requirements

- **Recovery input**: Support BOTH email and PID (username) - single identifier field
- **Security**: Always return generic responses - never reveal if email/pid exists
- **Token**: 1 hour expiration, cryptographically secure
- **Rate limiting**: 3 requests per hour using `pf::rate_limiter`
- **Email**: Send recovery link via existing activation email infrastructure

---

## Critical Design Decision: Use `activation` Table

**DO NOT** add columns to the `password` table. Instead, use the existing `activation` table with `type => 'password_reset'`.

### Why?

| Issue with Password Table | Activation Table Advantage |
|---------------------------|---------------------------|
| Single token per user (pid is PK) | Supports concurrent reset requests |
| No lifecycle management (no status column) | Built-in status: unverified → verified → invalidated |
| Must duplicate bcrypt/validation logic | Reuses `pf::activation` functions |
| Semantic mismatch (credentials vs tokens) | Designed for token-based flows |
| Violates existing patterns | Follows guest/sponsor activation pattern |

### Existing Infrastructure to Reuse

```perl
# Already exists in pf::activation:
pf::activation::create(\%args)                      # Create token record
pf::activation::validate_code($type, $code)         # Validate token
pf::activation::set_status_verified($type, $code)   # Mark as used
pf::activation::invalidate_codes($mac, $pid, $contact)  # Invalidate old tokens
```

---

## 1. Activation Module Updates

**File**: `/usr/local/pf/lib/pf/activation.pm`

### 1.1 New Type Constant

Add after existing type constants (around line 80):

```perl
Readonly our $PASSWORD_RESET_ACTIVATION => 'password_reset';
```

### 1.2 Export the Constant

Add to `@EXPORT_OK`:

```perl
@EXPORT_OK = qw(
    ...
    $PASSWORD_RESET_ACTIVATION
);
```

### 1.3 New Function: `create_and_send_password_reset`

```perl
sub create_and_send_password_reset {
    my ($pid, $email, $portal, %info) = @_;

    # Check rate limit (returns 1 if BLOCKED, 0 if allowed)
    if (pf::rate_limiter::is_pass_limit("password_reset:$pid", 3, 3600)) {
        return (0, "Rate limited");
    }

    # Invalidate any existing reset tokens for this user
    invalidate_codes(undef, $pid, $email, $PASSWORD_RESET_ACTIVATION);

    # Create activation record
    my %args = (
        pid => $pid,
        contact_info => $email,
        type => $PASSWORD_RESET_ACTIVATION,
        portal => $portal,
        timeout => 3600,  # 1 hour
    );

    my $activation_code = create(\%args);
    return (0, "Failed to create activation code") unless $activation_code;

    # Build activation URI
    $info{activation_uri} = "https://" . $Config{'general'}{'hostname'} . "."
        . $Config{'general'}{'domain'} . "/status/reset_password_token?token=$activation_code";
    $info{activation_timeout} = 3600;
    $info{pid} = $pid;
    $info{email} = $email;

    # Send email
    pf::config::util::send_email(
        'guest_password_reset',
        $email,
        i18n("Password Reset Request"),
        \%info
    );

    return (1, $activation_code);
}
```

---

## 2. Password Module Updates

**File**: `/usr/local/pf/lib/pf/password.pm`

### 2.1 New Function: `initiate_password_reset`

```perl
sub initiate_password_reset {
    my ($identifier) = @_;

    # Lookup user by PID first, then by email
    my $entry = view($identifier) // view_email($identifier);
    return (undef, undef) unless $entry;

    # Get email from person table
    my $person = pf::person::person_view($entry->{pid});
    my $email = $person->{email};
    return (undef, undef) unless $email;

    return ($entry->{pid}, $email);
}
```

### 2.2 New Function: `reset_password_with_token`

```perl
sub reset_password_with_token {
    my ($token, $new_password) = @_;

    # Validate token using activation module
    my $record = pf::activation::validate_code($pf::activation::PASSWORD_RESET_ACTIVATION, $token);
    return $FALSE unless $record;

    my $pid = $record->{pid};

    # Reset password using existing function
    my $result = reset_password($pid, $new_password);

    # Mark token as used
    if ($result) {
        pf::activation::set_status_verified($pf::activation::PASSWORD_RESET_ACTIVATION, $token);
    }

    return $result ? $pid : $FALSE;
}
```

---

## 3. Controller Updates

**File**: `/usr/local/pf/html/captive-portal/lib/captiveportal/PacketFence/Controller/Status.pm`

### 3.1 New Imports

```perl
use pf::activation qw($PASSWORD_RESET_ACTIVATION);
```

### 3.2 New Routes

| Route | Method | Description |
|-------|--------|-------------|
| `/status/forgot_password` | GET | Display recovery request form |
| `/status/forgot_password` | POST | Process request, send email |
| `/status/reset_password_token` | GET | Display reset form (with token param) |
| `/status/reset_password_token` | POST | Process password reset |

### 3.3 Route Implementation

```perl
sub forgot_password : Local {
    my ($self, $c) = @_;

    if ($c->request->method eq 'POST') {
        my $identifier = $c->request->param('identifier');

        # Always show success (security - no enumeration)
        $c->stash(template => 'status/forgot_password_sent.html');

        # Attempt to find user and send email
        my ($pid, $email) = pf::password::initiate_password_reset($identifier);

        if ($pid && $email) {
            pf::activation::create_and_send_password_reset(
                $pid, $email, $c->profile->getName, ()
            );
        }
        return;
    }

    # GET: display form
    $c->stash(template => 'status/forgot_password.html');
}

sub reset_password_token : Local {
    my ($self, $c) = @_;
    my $token = $c->request->param('token');

    if ($c->request->method eq 'POST') {
        my $password = $c->request->param('password');
        my $password2 = $c->request->param('password2');

        if (!$password || !$password2) {
            $c->stash(
                template => 'status/reset_password_token.html',
                token => $token,
                status => 'error_fill',
            );
            return;
        }

        if ($password ne $password2) {
            $c->stash(
                template => 'status/reset_password_token.html',
                token => $token,
                status => 'error_match',
            );
            return;
        }

        my $pid = pf::password::reset_password_with_token($token, $password);
        if ($pid) {
            $c->stash(template => 'status/reset_password_token_success.html');
        } else {
            $c->stash(template => 'status/reset_password_token_invalid.html');
        }
        return;
    }

    # GET: validate token and display form
    my $record = pf::activation::validate_code($pf::activation::PASSWORD_RESET_ACTIVATION, $token);

    if ($record) {
        $c->stash(
            template => 'status/reset_password_token.html',
            token => $token,
        );
    } else {
        $c->stash(template => 'status/reset_password_token_invalid.html');
    }
}
```

---

## 4. Portal Templates

**Location**: `/usr/local/pf/html/captive-portal/templates/status/`

### 4.1 Update Login Page

**File**: `login.html`

Add after submit button (around line 31):

```html
<div class="u-text-center u-margin-top">
  <a href="/status/forgot_password" class="c-btn c-btn--ghost u-1/1">[% i18n("Forgot your password?") %]</a>
</div>
```

### 4.2 New Template: `forgot_password.html`

```html
<div class="u-padding">
  <form name="forgot_password" method="post" action="/status/forgot_password">
    <div class="o-layout o-layout--center">
      <h5>[% i18n("Reset your password") %]</h5>
    </div>

    <div class="o-layout o-layout--center">
      <div class="o-layout__item u-1/1 u-2/3@tablet u-3/5@desktop">
        <div class="input-container">
          <label for="identifier">[% i18n("Username or Email") %]</label>
          <input class="field" name="identifier" id="identifier" type="text" required />
        </div>

        <button type="submit" name="submit" class="c-btn c-btn--primary u-1/1 u-margin-top">
          [% i18n("Send Reset Link") %]
        </button>

        <div class="u-text-center u-margin-top">
          <a href="/status/login">[% i18n("Back to Login") %]</a>
        </div>
      </div>
    </div>
  </form>
</div>
```

### 4.3 New Template: `forgot_password_sent.html`

```html
<div class="u-padding">
  <div class="o-media o-media--notice u-padding u-margin-bottom">
    <div class="o-media__img">[% flashIcon(level='notice', size='tiny') %]</div>
    <p class="o-media__body">[% i18n("If an account exists with that username or email, you will receive a password reset link shortly.") %]</p>
  </div>

  <div class="o-layout o-layout--center">
    <div class="o-layout__item u-1/1 u-2/3@tablet u-3/5@desktop">
      <div class="u-text-center u-margin-top">
        <a href="/status/login" class="c-btn c-btn--primary u-1/1">[% i18n("Back to Login") %]</a>
      </div>
    </div>
  </div>
</div>
```

### 4.4 New Template: `reset_password_token.html`

```html
<div class="u-padding">
  [% IF status == "error_match" %]
  <div class="o-media o-media--error u-padding u-margin-bottom">
    <div class="o-media__img">[% flashIcon(level='error') %]</div>
    <p class="o-media__body">[% i18n("The two entered passwords did not match") %]</p>
  </div>
  [% ELSIF status == "error_fill" %]
  <div class="o-media o-media--error u-padding u-margin-bottom">
    <div class="o-media__img">[% flashIcon(level='error') %]</div>
    <p class="o-media__body">[% i18n("Please fill in all fields") %]</p>
  </div>
  [% END %]

  <form name="reset_password_token" method="post" action="/status/reset_password_token">
    <input type="hidden" name="token" value="[% token %]" />

    <div class="o-layout o-layout--center">
      <h5>[% i18n("Set your new password") %]</h5>
    </div>

    <div class="o-layout o-layout--center">
      <div class="o-layout__item o-layout--left u-1/1 u-2/3@tablet u-3/5@desktop">
        <div class="input-container">
          <label for="password">[% i18n("New Password") %]</label>
          <input class="field" name="password" id="password" type="password" required />
        </div>
        <div class="input-container">
          <label for="password2">[% i18n("Confirm Password") %]</label>
          <input class="field" name="password2" id="password2" type="password" required />
        </div>

        <button type="submit" name="submit" class="c-btn c-btn--primary u-1/1 u-margin-top">
          [% i18n("Reset Password") %]
        </button>
      </div>
    </div>
  </form>
</div>
```

### 4.5 New Template: `reset_password_token_invalid.html`

```html
<div class="u-padding">
  <div class="o-media o-media--error u-padding u-margin-bottom">
    <div class="o-media__img">[% flashIcon(level='error') %]</div>
    <p class="o-media__body">[% i18n("This password reset link is invalid or has expired.") %]</p>
  </div>

  <div class="o-layout o-layout--center">
    <div class="o-layout__item u-1/1 u-2/3@tablet u-3/5@desktop">
      <div class="u-text-center u-margin-top">
        <a href="/status/forgot_password" class="c-btn c-btn--primary u-1/1">[% i18n("Request a new link") %]</a>
      </div>
    </div>
  </div>
</div>
```

### 4.6 New Template: `reset_password_token_success.html`

```html
<div class="u-padding">
  <div class="o-media o-media--notice u-padding u-margin-bottom">
    <div class="o-media__img">[% flashIcon(level='notice', size='tiny') %]</div>
    <p class="o-media__body">[% i18n("Your password has been reset successfully.") %]</p>
  </div>

  <div class="o-layout o-layout--center">
    <div class="o-layout__item u-1/1 u-2/3@tablet u-3/5@desktop">
      <div class="u-text-center u-margin-top">
        <a href="/status/login" class="c-btn c-btn--primary u-1/1">[% i18n("Login") %]</a>
      </div>
    </div>
  </div>
</div>
```

---

## 5. Email Template

**File**: `/usr/local/pf/html/captive-portal/templates/emails/emails-guest_password_reset.html`

### Template Variables (following existing patterns)
- `[% activation_uri %]` - Full URL with token (NOT `reset_url`)
- `[% activation_timeout %]` - Token validity in seconds
- `[% pid %]` - Username

### HTML Template

Follow structure from `emails-guest_email_activation.html`:

```html
<!-- Standard email structure with activation_uri button -->
<a href="[% activation_uri %]" class="button">[% i18n("Reset Password") %]</a>
<p>[% i18n_format("This link will expire in %s minutes.", activation_timeout / 60) %]</p>
```

---

## 6. Security Measures

| Concern | Mitigation |
|---------|------------|
| User enumeration | Always return generic "check your email" response |
| Token brute force | Rate limit 3 requests/hour via `pf::rate_limiter` |
| Token storage | Uses existing activation table hashing |
| Token reuse | `set_status_verified()` marks token as used |
| Concurrent requests | Previous tokens invalidated via `invalidate_codes()` |
| Long-lived tokens | 1-hour expiration |

---

## 7. Files to Create/Modify

### New Files (6)
1. `/usr/local/pf/html/captive-portal/templates/status/forgot_password.html`
2. `/usr/local/pf/html/captive-portal/templates/status/forgot_password_sent.html`
3. `/usr/local/pf/html/captive-portal/templates/status/reset_password_token.html`
4. `/usr/local/pf/html/captive-portal/templates/status/reset_password_token_invalid.html`
5. `/usr/local/pf/html/captive-portal/templates/status/reset_password_token_success.html`
6. `/usr/local/pf/html/captive-portal/templates/emails/emails-guest_password_reset.html`

### Modified Files (4)
1. `/usr/local/pf/lib/pf/activation.pm` - Add constant + `create_and_send_password_reset()`
2. `/usr/local/pf/lib/pf/password.pm` - Add `initiate_password_reset()` + `reset_password_with_token()`
3. `/usr/local/pf/html/captive-portal/lib/captiveportal/PacketFence/Controller/Status.pm` - Add 2 routes
4. `/usr/local/pf/html/captive-portal/templates/status/login.html` - Add forgot password link

### NO Database Changes Required
The `activation` table already supports the `password_reset` type - no schema modifications needed.

---

## 8. Verification

### Manual Testing
1. Navigate to `/status/login` - verify "Forgot password?" link appears
2. Click link - verify form displays with username/email field
3. Enter valid email - verify "check email" message
4. Enter invalid email - verify same "check email" message (no enumeration)
5. Check email - verify recovery link received with correct URL
6. Click link - verify reset form displays
7. Enter mismatched passwords - verify error
8. Enter matching passwords - verify success
9. Try using expired token (wait >1 hour) - verify error
10. Try using same token twice - verify error (already verified)
11. Submit 4+ requests in 1 hour - verify rate limiting

### Database Verification
```sql
-- Check activation records
SELECT code_id, pid, contact_info, type, status, expiration
FROM activation
WHERE type = 'password_reset';
```

### Rate Limiter Verification
```bash
redis-cli KEYS "RateLimiter:password_reset:*"
```
