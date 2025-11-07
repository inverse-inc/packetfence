## Captive Portal CSS Themes

This directory contains advanced CSS themes for the PacketFence captive portal. Each theme features carefully selected color palettes, custom typography, gradient backgrounds, and modern button styling to create distinct visual experiences for different venue types.

## Available Themes

### 1. **default** - Standard PacketFence
Standard PacketFence color scheme with no custom overrides.

### 2. **hotel** - Elegant & Sophisticated
**Color Palette**: Beige (#DDD0C8) and Dark Gray (#323232)
- **Style**: Soft, elegant gradients with subtle shadows
- **Typography**: Segoe UI with light font weights
- **Buttons**: Rounded (24px) with gradient effects and hover animations
- **Best For**: Luxury hotels, business hotels, hospitality venues

### 3. **restaurant** - Warm & Harmonious
**Color Palette**: Deep Blue (#001233), Light Coral Red (#FF595A), Beige (#CAC0B3)
- **Style**: 3-color harmony with warm gradients
- **Typography**: Georgia serif for warmth, Sans-serif for headings
- **Buttons**: Medium rounded (25px) with multi-color gradient accents
- **Best For**: Fine dining, cafes, bistros, culinary venues

### 4. **sport-event** - Dynamic & Energetic
**Color Palette**: Blue (#00ABE4) and Orange (#FFCC00)
- **Style**: High energy with bold gradients and strong shadows
- **Typography**: Roboto with bold font weights (700)
- **Buttons**: Large rounded (28px) with scale transform on hover
- **Best For**: Sports stadiums, gyms, athletic facilities, event venues

### 5. **fastfood** - Bold & Appetizing
**Color Palette**: Bright Red (#e63946), White (#FFFFFF), Yellow (#f4a127)
- **Style**: Clean white background with bold color accents
- **Typography**: Arial with heavy weights (800) and uppercase
- **Buttons**: Extra rounded (32px) with large padding and bold borders
- **Best For**: Quick service restaurants, fast food chains, food courts

### 6. **university** - Academic & Minimalist
**Color Palette**: Tyrian Purple (#4F0341) and White (#FFFFFF)
- **Style**: Clean minimalist design with subtle shadows
- **Typography**: Georgia serif with moderate weights
- **Buttons**: Minimal rounded (4px) with clean lines
- **Best For**: Universities, colleges, schools, educational institutions

### 7. **retail** - Energetic & Joyful
**Color Palette**: Malachite Green (#31EC56) and Bright Pink (#EF036C)
- **Style**: Fresh vibrant design with gradient borders
- **Typography**: Modern sans-serif with medium weights
- **Buttons**: Highly rounded (30px) with vibrant gradients
- **Best For**: Shopping malls, retail stores, boutiques, modern brands

### 8. **home** - Cozy & Comfortable
**Color Palette**: Soft Green (#6a994e), Warm Wood (#a67c52), Cream
- **Style**: Natural, warm tones with soft shadows
- **Typography**: Friendly sans-serif with regular weights
- **Buttons**: Soft rounded (20px) with gentle gradients
- **Best For**: Residential WiFi, home networks, co-working spaces

## Configuration

### Setting a Theme via Configuration File

Edit `/usr/local/pf/conf/profiles.conf`:

```ini
[my_hotel_profile]
description=Hotel WiFi Portal
portal_css_theme=hotel
logo=/profile-templates/hotel/logo.png
sources=my_auth_source
redirecturl=https://hotel.example.com/welcome
```

### Setting a Theme via Admin Interface

1. Navigate to **Configuration → Connection Profiles**
2. Edit or create a connection profile
3. Go to the **Captive Portal** tab
4. Select a theme from the **Portal CSS Theme** dropdown
5. Save the profile

### Applying Changes

After modifying the configuration, reload PacketFence:

```bash
/usr/local/pf/bin/pfcmd configreload hard
/usr/local/pf/bin/pfcmd service httpd.portal restart
```

## Theme Features

All themes include:

### Advanced Typography
- Custom font families optimized for each venue type
- Adjusted font weights and letter spacing
- Improved line height for readability

### Modern Backgrounds
- Linear gradients for visual depth
- Subtle color transitions
- Backdrop blur effects on some themes

### Enhanced Buttons
- Gradient backgrounds
- Custom border radius
- Smooth hover animations (translateY, scale)
- Box shadow effects
- Focus states for accessibility

### Improved Inputs
- Soft border colors
- Focus ring effects
- Custom padding
- Transition animations

### Refined Notifications
- Custom border styling
- Gradient backgrounds
- Icon color matching
- Rounded corners

## Color Reference

### Hotel (Beige & Gray)
- Primary: #A08D7E (Taupe)
- Secondary: #323232 (Dark Gray)
- Background: #DDD0C8 (Beige)

### Restaurant (Blue, Coral, Beige)
- Primary: #FF595A (Coral Red)
- Secondary: #001233 (Deep Blue)
- Accent: #CAC0B3 (Beige)

### Sport Event (Blue & Orange)
- Primary: #FFCC00 (Bright Orange)
- Secondary: #00ABE4 (Cyan Blue)
- Background: Light blue-yellow gradient

### Fast Food (Red & Yellow)
- Primary: #e63946 (Bright Red)
- Secondary: #f4a127 (Golden Yellow)
- Background: #FFFFFF (Pure White)

### University (Purple & White)
- Primary: #4F0341 (Tyrian Purple)
- Secondary: #FFFFFF (White)
- Background: Off-white

### Retail (Green & Pink)
- Primary: #31EC56 (Malachite Green)
- Secondary: #EF036C (Bright Pink)
- Border: Gradient (Green to Pink)

### Home (Green & Wood)
- Primary: #6a994e (Soft Green)
- Secondary: #a67c52 (Warm Wood)
- Background: #faf8f3 (Cream)

## Creating Custom Themes

To create a custom theme:

1. **Create a new CSS file** in this directory (e.g., `custom.css`)

2. **Use this template structure**:

```css
/**
 * Custom Theme Name
 * Description of the theme
 * Colors: List your main colors
 */

/* Typography */
html, body {
  font-family: 'Your Font', sans-serif !important;
  color: #yourcolor !important;
}

/* Backgrounds */
html {
  background: linear-gradient(135deg, #color1 0%, #color2 100%) !important;
}

.c-frame {
  background-color: #yourcolor !important;
  border-radius: 16px !important;
}

/* Buttons */
.c-btn--primary, a.c-btn--primary {
  background: linear-gradient(135deg, #color1 0%, #color2 100%) !important;
  border-radius: 25px !important;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
}

/* Add more customizations... */
```

3. **Set the theme** in your connection profile:
```ini
portal_css_theme=custom
```

## CSS Architecture

### Cascade Order
1. Base styles from `/common/styles.css`
2. Theme overrides from `/common/themes/{theme}.css`

### !important Usage
All theme styles use `!important` to ensure they override the compiled base styles.

### Browser Support
Themes support modern browsers with:
- CSS gradients
- Border radius
- Box shadows
- Transforms
- Transitions
- Backdrop filters (with fallbacks)

## Tips

1. **Test thoroughly**: View the portal on different devices and browsers
2. **Consider accessibility**: Ensure sufficient color contrast
3. **Match branding**: Choose themes that align with your venue's brand
4. **Logo coordination**: Update the logo to match your chosen theme
5. **Localization**: Themes work with all supported languages

## Support

For issues or questions:
- Report bugs: https://github.com/inverse-inc/packetfence/issues
- Documentation: https://packetfence.org/doc/
- Community: https://packetfence.org/support/community.html
