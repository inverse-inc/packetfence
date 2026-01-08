# Password Recovery for Captive Portal - Implementation Plan

## Overview

Add unauthenticated password recovery to the captive portal, allowing users to reset their password via email without being logged in.

## Requirements

- **Recovery input**: Support BOTH email and PID (username) - single identifier field
- **Security**: Always return generic responses - never reveal if email/pid exists
- **Token**: 1 hour expiration, cryptographically secure
- **Rate limiting**: 3 requests per hour using `pf::rate_limiter`
- **Email**: Send recovery link via SMTP (configured in `[alerting]` section)

---

## 1. Database Changes

### 1.1 Schema Updates

**File**: `/usr/local/pf/db/pf-schema-15.0.sql` (update password table definition)

Add 2 columns to the `password` table:
```sql
`password_reset_token` varchar(255) DEFAULT NULL,
`password_reset_token_expiration` datetime DEFAULT NULL,
```

### 1.2 Upgrade Script

**File**: `/usr/local/pf/db/upgrade-15.0-15.1.sql` (new file)

```sql
SET sql_mode = "NO_ENGINE_SUBSTITUTION";

--
-- PacketFence SQL schema upgrade from 15.0 to 15.1
--

SET @MAJOR_VERSION = 15;
SET @MINOR_VERSION = 1;
SET @PREV_MAJOR_VERSION = 15;
SET @PREV_MINOR_VERSION = 0;

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8;
SET @PREV_VERSION_INT = @PREV_MAJOR_VERSION << 16 | @PREV_MINOR_VERSION << 8;

DROP PROCEDURE IF EXISTS ValidateVersion;
DELIMITER //
CREATE PROCEDURE ValidateVersion()
BEGIN
    DECLARE PREVIOUS_VERSION int(11);
    DECLARE PREVIOUS_VERSION_STRING varchar(11);
    DECLARE _message varchar(255);
    SELECT id, version INTO PREVIOUS_VERSION, PREVIOUS_VERSION_STRING FROM pf_version ORDER BY id DESC LIMIT 1;

    IF PREVIOUS_VERSION != @PREV_VERSION_INT THEN
        SELECT CONCAT('PREVIOUS VERSION ', PREVIOUS_VERSION_STRING, ' DOES NOT MATCH ', CONCAT_WS('.', @PREV_MAJOR_VERSION, @PREV_MINOR_VERSION)) INTO _message;
        SIGNAL SQLSTATE VALUE '99999' SET MESSAGE_TEXT = _message;
    END IF;
END
//
DELIMITER ;

\! echo "Checking PacketFence schema version...";
call ValidateVersion;
DROP PROCEDURE IF EXISTS ValidateVersion;

\! echo "Adding password reset columns to password table";
ALTER TABLE `password`
    ADD COLUMN IF NOT EXISTS `password_reset_token` varchar(255) DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `password_reset_token_expiration` datetime DEFAULT NULL;

\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version, created_at) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION), NOW());

\! echo "Upgrade completed successfully.";
```

### 1.3 DAL Update

**File**: `/usr/local/pf/lib/pf/dal/_password.pm`

Add new columns to the `@COLUMN_NAMES` and `@INSERTABLE_FIELDS` arrays:
- `password_reset_token`
- `password_reset_token_expiration`

---

## 2. Password Module Functions

**File**: `/usr/local/pf/lib/pf/password.pm`

### 2.1 New Constants

```perl
Readonly::Scalar our $RESET_TOKEN_EXPIRATION => 3600;  # 1 hour in seconds
Readonly::Scalar our $RESET_RATE_LIMIT => 3;          # 3 requests per hour
Readonly::Scalar our $RESET_RATE_WINDOW => 3600;      # 1 hour window
```

### 2.2 New Functions

#### `generate_password_reset_token($identifier)`
- Lookup user by PID first, then by email using `view()` and `view_email()`
- Check rate limit using `pf::rate_limiter::is_pass_limit("password_reset:$identifier", 3, 3600)`
- Generate 32-byte secure random token using `Bytes::Random::Secure`
- Hash token with bcrypt before storing (same pattern as password hashing)
- Store hashed token and expiration in password table
- Return `($plaintext_token, $email, $pid)` or `(undef, undef, undef)`

#### `validate_password_reset_token($token)`
- Query all non-expired tokens from password table
- Use bcrypt constant-time comparison to check each token
- Return `$pid` if valid, `undef` if invalid/expired

#### `reset_password_with_token($token, $new_password)`
- Call `validate_password_reset_token()` to get PID
- Call existing `reset_password($pid, $new_password)`
- Clear token columns after successful reset
- Return `$TRUE` or `$FALSE`

---

## 3. Controller Updates

**File**: `/usr/local/pf/html/captive-portal/lib/captiveportal/PacketFence/Controller/Status.pm`

### 3.1 New Imports

```perl
use pf::rate_limiter;
use pf::config::util qw(send_email);
```

### 3.2 New Routes

| Route | Method | Description |
|-------|--------|-------------|
| `/status/forgot_password` | GET | Display recovery request form |
| `/status/forgot_password_request` | POST | Process request, send email |
| `/status/reset_password_token` | GET | Display reset form (with token param) |
| `/status/reset_password_token_submit` | POST | Process password reset with token |

### 3.3 Route Implementation

#### `forgot_password` (GET)
- Simply render `status/forgot_password.html` template

#### `forgot_password_request` (POST)
- Get `identifier` param (username or email)
- **Always** render success template (security)
- Call `pf::password::generate_password_reset_token($identifier)`
- If token returned, send email via `pf::config::util::send_email()`
- Email template: `guest_password_reset`

#### `reset_password_token` (GET)
- Get `token` param from URL
- Validate with `pf::password::validate_password_reset_token()`
- If valid: render `status/reset_password_token.html` with token
- If invalid: render `status/reset_password_token_invalid.html`

#### `reset_password_token_submit` (POST)
- Get `token`, `password`, `password2` params
- Validate passwords match
- Call `pf::password::reset_password_with_token()`
- Render success or error template

---

## 4. Portal Templates

**Location**: `/usr/local/pf/html/captive-portal/templates/status/`

### 4.1 Update Login Page

**File**: `status/login.html`

Add "Forgot Password" link after the submit button (line 31):

```html
        <button type="submit" name="submit" class="c-btn c-btn--primary u-1/1 u-margin-top" disabled>
          [% i18n("Login") %]
        </button>

        [%# Forgot Password Link %]
        <div class="u-text-center u-margin-top">
          <a href="/status/forgot_password" class="c-link">[% i18n("Forgot your password?") %]</a>
        </div>
```

### 4.2 New Templates

| File | Purpose |
|------|---------|
| `forgot_password.html` | Form to enter email/username |
| `forgot_password_sent.html` | Generic "check your email" message |
| `reset_password_token.html` | Form to set new password (with hidden token) |
| `reset_password_token_invalid.html` | Token expired/invalid message |
| `reset_password_token_success.html` | Password reset success message |

---

## 5. Email Template

**Files**:
- `/usr/local/pf/html/captive-portal/templates/emails/emails-guest_password_reset.mjml`
- `/usr/local/pf/html/captive-portal/templates/emails/emails-guest_password_reset.html`

### Template Variables
- `[% reset_url %]` - Full URL with token
- `[% pid %]` - Username
- `[% expiration_minutes %]` - Token validity (60)

### MJML Structure
Follow existing pattern from `emails-guest_email_activation.mjml`:
- Include `_header.mjml` and `_footer.mjml`
- Use `[% i18n("text") %]` for all strings
- Button with `href="[% reset_url %]"`

### Compile to HTML
```bash
cd /usr/local/pf/html/captive-portal/templates/emails
npx mjml emails-guest_password_reset.mjml -o emails-guest_password_reset.html
```

---

## 6. OAS Specification

**File**: `/usr/local/pf/docs/api/spec/static/components/schemas/password.yaml`

Add new properties to Password schema:
```yaml
password_reset_token:
  type: string
  description: Hashed password reset token
password_reset_token_expiration:
  type: string
  format: date-time
  description: Token expiration timestamp
```

---

## 7. Security Measures

| Concern | Mitigation |
|---------|------------|
| User enumeration | Always return generic "check your email" response |
| Token brute force | Rate limit 3 requests/hour via `pf::rate_limiter` |
| Token interception | Tokens hashed with bcrypt before storage |
| Timing attacks | Use constant-time bcrypt comparison |
| Token reuse | Clear token after successful reset |
| Long-lived tokens | 1-hour expiration |

---

## 8. Files to Create/Modify

### New Files
- `/usr/local/pf/db/upgrade-15.0-15.1.sql`
- `/usr/local/pf/html/captive-portal/templates/status/forgot_password.html`
- `/usr/local/pf/html/captive-portal/templates/status/forgot_password_sent.html`
- `/usr/local/pf/html/captive-portal/templates/status/reset_password_token.html`
- `/usr/local/pf/html/captive-portal/templates/status/reset_password_token_invalid.html`
- `/usr/local/pf/html/captive-portal/templates/status/reset_password_token_success.html`
- `/usr/local/pf/html/captive-portal/templates/emails/emails-guest_password_reset.mjml`
- `/usr/local/pf/html/captive-portal/templates/emails/emails-guest_password_reset.html`

### Modified Files
- `/usr/local/pf/db/pf-schema-15.0.sql` - Add columns to password table
- `/usr/local/pf/lib/pf/dal/_password.pm` - Add new columns
- `/usr/local/pf/lib/pf/password.pm` - Add token functions
- `/usr/local/pf/html/captive-portal/lib/captiveportal/PacketFence/Controller/Status.pm` - Add routes
- `/usr/local/pf/html/captive-portal/templates/status/login.html` - Add forgot link
- `/usr/local/pf/docs/api/spec/static/components/schemas/password.yaml` - Add fields

---

## 9. Verification

### Manual Testing
1. Navigate to `/status/login` - verify "Forgot password?" link appears
2. Click link - verify form displays
3. Enter valid email - verify "check email" message
4. Enter invalid email - verify same "check email" message (no enumeration)
5. Check email - verify recovery link received
6. Click link - verify reset form displays
7. Enter mismatched passwords - verify error
8. Enter matching passwords - verify success
9. Try using expired/invalid token - verify error message
10. Try using same token twice - verify error (already used)
11. Submit 4+ requests in 1 hour - verify rate limiting (still shows success message)

### Database Verification
```sql
-- Check new columns exist
DESCRIBE password;

-- Check token storage after request
SELECT pid, password_reset_token, password_reset_token_expiration
FROM password WHERE password_reset_token IS NOT NULL;
```

### Rate Limiter Verification
```bash
# Check Redis for rate limit keys
redis-cli KEYS "RateLimiter:password_reset:*"
```
