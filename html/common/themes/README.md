## Captive Portal CSS Themes

This directory contains professional CSS themes for the PacketFence captive portal, inspired by popular WordPress themes and modern design frameworks. Each theme follows established design patterns, typography systems, and styling conventions to provide professional and familiar visual experiences for different venue types.

## Available Themes

### 1. **default** - Standard PacketFence
Standard PacketFence color scheme with no custom overrides.

### 2. **astra** - Clean & Minimal (Hotel/Business)
**Inspired by**: Astra WordPress Theme
**Color Palette**: Taupe (#A08D7E) and Dark Gray (#323232)
- **Style**: Clean and readable with minimal design
- **Typography**: System fonts (-apple-system, Segoe UI) with 15px base size
- **Buttons**: 3px border radius, subtle shadows, smooth linear transitions (0.2s)
- **Inputs**: 2px borders with focus ring effects
- **Best For**: Hotels, business centers, corporate WiFi, professional venues

### 3. **generatepress** - Lightweight & Minimal (Restaurant)
**Inspired by**: GeneratePress WordPress Theme
**Color Palette**: Coral Red (#FF595A) and Deep Blue (#001233)
- **Style**: Extremely lightweight with no-frills design
- **Typography**: System fonts, 14px base, uppercase text transforms
- **Buttons**: No border radius (sharp corners), uppercase text, letter-spacing
- **Inputs**: Border-bottom only design
- **Best For**: Restaurants, cafes, bistros, dining establishments

### 4. **oceanwp** - Modern & Bold (Sport Event)
**Inspired by**: OceanWP WordPress Theme
**Color Palette**: Cyan Blue (#00ABE4) and Orange (#FFCC00)
- **Style**: Modern and vibrant with good use of whitespace
- **Typography**: Lato font, 16px base, 1.8 line-height, bold headings (700)
- **Buttons**: 4px radius, uppercase (letter-spacing: 1px), translateY hover animations
- **Inputs**: Clean borders with subtle focus shadows
- **Best For**: Sports stadiums, gyms, athletic facilities, event venues

### 5. **neve** - Fast & Clean (Fast Food)
**Inspired by**: Neve WordPress Theme
**Color Palette**: Bright Red (#e63946) and Yellow (#f4a127)
- **Style**: Fast, clean lines with minimal overhead
- **Typography**: System fonts, 15px base, 1.6 line-height
- **Buttons**: 3px radius, no box shadows, fast transitions (0.15s ease-in-out)
- **Inputs**: Clean borders with Bootstrap-like focus rings
- **Best For**: Fast food chains, quick service restaurants, food courts

### 6. **divi** - Elegant & Sophisticated (University/Education)
**Inspired by**: Divi WordPress Theme
**Color Palette**: Tyrian Purple (#4F0341) and White
- **Style**: Elegant and refined with sophisticated transitions
- **Typography**: Open Sans, 14px base, 1.7em line-height, refined headings
- **Buttons**: 3px radius, border transitions (solid to transparent), 0.4s ease-in-out
- **Inputs**: Border-bottom only with transparent backgrounds
- **Best For**: Universities, colleges, schools, educational institutions

### 7. **hestia** - Material Design (Retail/Shop)
**Inspired by**: Hestia WordPress Theme
**Color Palette**: Malachite Green (#31EC56) and Bright Pink (#EF036C)
- **Style**: Material Design with raised card effects
- **Typography**: Roboto and Roboto Slab fonts, Material Design sizing (rem units)
- **Buttons**: 3px radius, layered Material shadows, cubic-bezier transitions
- **Inputs**: Border-bottom only, Material Design focus effects
- **Best For**: Shopping malls, retail stores, boutiques, modern brands

### 8. **blocksy** - Modern & Flexible (Home/Residential)
**Inspired by**: Blocksy WordPress Theme
**Color Palette**: Soft Green (#6a994e) and Warm Wood (#a67c52)
- **Style**: Modern, flexible with excellent typography and spacing
- **Typography**: System fonts, 18px base, 1.65 line-height, 700 weight headings
- **Buttons**: 5px radius, subtle shadows, translateY(-1px) hover effects
- **Inputs**: 2px borders, rounded inputs with focus rings
- **Best For**: Residential WiFi, home networks, co-working spaces, apartments

### 9. **material** - Material Design (Modern/Tech)
**Inspired by**: Google Material Design
**Color Palette**: Blue (#2196F3) and Pink Accent (#FF4081)
- **Style**: Elevation-based design with layered shadows and motion
- **Typography**: Roboto font family, Material Design type scale
- **Buttons**: 4px radius, raised elevation shadows, cubic-bezier(0.4, 0, 0.2, 1) transitions (250ms)
- **Inputs**: Filled style with bottom border, hover states, 2px focus indicators
- **Design System**: Google's Material Design 2.0 with proper elevation levels
- **Best For**: Tech companies, startups, modern businesses, coworking spaces, innovation hubs

### 10. **bootstrap** - Bootstrap Framework (Classic/Utility)
**Inspired by**: Twitter Bootstrap
**Color Palette**: Primary Blue (#007bff) and Secondary Gray (#6c757d)
- **Style**: Utility-first approach with consistent spacing and borders
- **Typography**: System font stack, rem-based sizing (16px base)
- **Buttons**: 0.25rem radius, focus rings with box-shadow, 0.15s ease-in-out transitions
- **Inputs**: Standard form controls with validation states (valid/invalid)
- **Design System**: Bootstrap 4.x design patterns with utility classes
- **Best For**: Corporate environments, enterprise, government, healthcare, general purpose

## Configuration

### Setting a Theme via Configuration File

Edit `/usr/local/pf/conf/profiles.conf`:

```ini
[my_hotel_profile]
description=Hotel WiFi Portal
portal_css_theme=astra
logo=/profile-templates/hotel/logo.png
sources=my_auth_source
redirecturl=https://hotel.example.com/welcome

[my_restaurant_profile]
description=Restaurant WiFi
portal_css_theme=generatepress
sources=my_auth_source

[my_university_profile]
description=Campus WiFi
portal_css_theme=divi
sources=university_ldap
```

### Setting a Theme via Admin Interface

1. Navigate to **Configuration → Connection Profiles**
2. Edit or create a connection profile
3. Go to the **Captive Portal** tab
4. Select a theme from the **Portal CSS Theme** dropdown:
   - **Astra (Hotel/Business)**
   - **GeneratePress (Restaurant)**
   - **OceanWP (Sport Event)**
   - **Neve (Fast Food)**
   - **Divi (University/Education)**
   - **Hestia (Retail/Shop)**
   - **Blocksy (Home/Residential)**
   - **Material Design (Modern/Tech)**
   - **Bootstrap (Classic/Utility)**
5. Save the profile

### Applying Changes

After modifying the configuration, reload PacketFence:

```bash
/usr/local/pf/bin/pfcmd configreload hard
/usr/local/pf/bin/pfcmd service httpd.portal restart
```

## WordPress Theme Characteristics

### Astra (astra.css)
- **Border Radius**: 3px (consistent)
- **Shadows**: Subtle (0 1px 3px)
- **Transitions**: Linear, 0.2s
- **Font Weight**: 600 for buttons
- **Philosophy**: Minimal overhead, clean readability

### GeneratePress (generatepress.css)
- **Border Radius**: 0px (sharp corners)
- **Shadows**: Minimal to none
- **Transitions**: Ease-in-out, 0.3s
- **Font Weight**: 600 for buttons
- **Text Transform**: Uppercase with letter-spacing
- **Philosophy**: Lightweight, performance-focused

### OceanWP (oceanwp.css)
- **Border Radius**: 4px
- **Shadows**: Strong on hover (0 5px 15px)
- **Transitions**: Ease, 0.3s
- **Font Weight**: 700 (bold)
- **Text Transform**: Uppercase with 1px letter-spacing
- **Animations**: translateY(-2px) on hover
- **Philosophy**: Modern, feature-rich, good whitespace

### Neve (neve.css)
- **Border Radius**: 3px
- **Shadows**: Minimal, Bootstrap-inspired focus rings
- **Transitions**: Fast ease-in-out, 0.15s
- **Font Weight**: 500
- **Philosophy**: Fast, clean, minimal animations

### Divi (divi.css)
- **Border Radius**: 3px
- **Shadows**: Soft (0 0 15px)
- **Transitions**: Slow ease-in-out, 0.4s
- **Font Weight**: 500
- **Button Effect**: Solid to transparent border on hover
- **Philosophy**: Elegant, sophisticated, refined transitions

### Hestia (hestia.css)
- **Border Radius**: 6px
- **Shadows**: Layered Material Design shadows
- **Transitions**: Cubic-bezier (Material motion)
- **Font Weight**: 400
- **Text Transform**: Uppercase
- **Philosophy**: Material Design, raised card effects

### Blocksy (blocksy.css)
- **Border Radius**: 5px
- **Shadows**: Subtle layered (0 1px 3px)
- **Transitions**: Ease, 0.25s
- **Font Weight**: 600 for buttons
- **Font Size**: Larger base (18px)
- **Animations**: Subtle translateY(-1px)
- **Philosophy**: Modern, flexible, excellent typography

### Material Design (material.css)
- **Border Radius**: 4px
- **Shadows**: Elevation-based with 3 layers (rest, hover, active states)
- **Transitions**: Cubic-bezier(0.4, 0, 0.2, 1), 250ms (Material motion)
- **Font Weight**: 400-500 (Material Design scale)
- **Text Transform**: Uppercase with 0.02857em letter-spacing
- **Typography**: Roboto font family with Material Design type scale
- **Philosophy**: Google's Material Design 2.0, elevation and motion principles

### Bootstrap (bootstrap.css)
- **Border Radius**: 0.25rem (4px)
- **Shadows**: Minimal (0.125rem 0.25rem), focus rings with 0.2rem spread
- **Transitions**: Ease-in-out, 0.15s (fast and responsive)
- **Font Weight**: 400-500
- **Units**: Rem-based spacing (1rem = 16px)
- **Validation**: Built-in valid/invalid states
- **Philosophy**: Utility-first, Bootstrap 4.x design patterns

## Color Reference

### Astra (Hotel/Business)
- Primary: #A08D7E (Taupe)
- Secondary: #323232 (Dark Gray)
- Background: #f7f7f7 (Light Gray)

### GeneratePress (Restaurant)
- Primary: #FF595A (Coral Red)
- Secondary: #001233 (Deep Blue)
- Accent: #CAC0B3 (Beige)

### OceanWP (Sport Event)
- Primary: #00ABE4 (Cyan Blue)
- Secondary: #FFCC00 (Bright Orange)
- Background: #f8f8f8

### Neve (Fast Food)
- Primary: #e63946 (Bright Red)
- Secondary: #f4a127 (Golden Yellow)
- Background: #ffffff (Pure White)

### Divi (University/Education)
- Primary: #4F0341 (Tyrian Purple)
- Background: #ffffff (White)

### Hestia (Retail/Shop)
- Primary: #EF036C (Bright Pink)
- Secondary: #31EC56 (Malachite Green)
- Background: #e5e5e5 (Material Gray)

### Blocksy (Home/Residential)
- Primary: #6a994e (Soft Green)
- Secondary: #a67c52 (Warm Wood)
- Background: #f9fafb (Off White)

### Material Design (Modern/Tech)
- Primary: #2196F3 (Material Blue)
- Secondary: #FF4081 (Pink Accent)
- Background: #fafafa (Material Gray 50)
- Success: #4CAF50 (Material Green)
- Error: #F44336 (Material Red)

### Bootstrap (Classic/Utility)
- Primary: #007bff (Bootstrap Blue)
- Secondary: #6c757d (Bootstrap Gray)
- Success: #28a745 (Bootstrap Green)
- Danger: #dc3545 (Bootstrap Red)
- Warning: #ffc107 (Bootstrap Yellow)
- Info: #17a2b8 (Bootstrap Cyan)
- Background: #f8f9fa (Light Gray)

## Creating Custom Themes

To create a custom WordPress-inspired theme:

1. **Choose a WordPress theme** to emulate (check their official sites for design patterns)

2. **Create a new CSS file** in this directory (e.g., `avada.css`)

3. **Follow WordPress theme patterns**:

```css
/**
 * Custom Theme Name - WordPress Theme Style
 * Description of the theme
 * Colors: List your main colors
 */

/* WordPress-style Typography */
html, body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif !important;
  font-size: 15px;
  line-height: 1.6;
  color: #333333 !important;
}

h1, h2, h3, h4, h5, h6 {
  font-family: inherit !important;
  font-weight: 600 !important;
  line-height: 1.3 !important;
}

/* Clean background */
html {
  background: #ffffff !important;
}

.c-frame {
  background: #ffffff !important;
  border: 1px solid #e0e0e0 !important;
  border-radius: 4px !important;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1) !important;
}

/* WordPress-style buttons */
.c-btn--primary, a.c-btn--primary {
  background: #0073aa !important;
  color: #ffffff !important;
  border: 0 !important;
  border-radius: 3px !important;
  padding: 10px 20px !important;
  transition: background-color 0.2s ease !important;
}

.c-btn--primary:hover {
  background: #005177 !important;
}
```

4. **Add to ProfileCommon.pm** options:
```perl
{ value => 'avada', label => 'Avada (Custom Use)' },
```

## CSS Architecture

### Cascade Order
1. Base styles from `/common/styles.css`
2. Theme overrides from `/common/themes/{theme}.css`

### !important Usage
All theme styles use `!important` to ensure they override the compiled base styles.

### Design Philosophy
Each theme follows its design system's philosophy:
- **Performance**: Neve and GeneratePress minimize CSS overhead
- **Flexibility**: Blocksy and Astra provide balanced customization
- **Features**: OceanWP offers rich styling options
- **Elegance**: Divi focuses on sophisticated transitions
- **Material Design**: Hestia and Material themes implement Google's Material Design principles
- **Elevation & Motion**: Material theme uses proper elevation levels and motion curves
- **Utility-First**: Bootstrap provides consistent spacing and utility classes

### Browser Support
Themes support modern browsers with:
- CSS transitions and transforms
- Border radius and box shadows
- System font stacks for performance
- Focus states for accessibility

## Tips

1. **Match WordPress theme to venue**: Each theme's personality suits different contexts
2. **Test thoroughly**: View the portal on different devices and browsers
3. **Consider accessibility**: All themes maintain WCAG-compliant color contrast
4. **Match branding**: Choose themes that align with your venue's brand
5. **Logo coordination**: Update the logo to match your chosen theme colors
6. **Localization**: Themes work with all supported languages

## Design System Resources

### WordPress Themes
- **Astra**: https://wpastra.com/
- **GeneratePress**: https://generatepress.com/
- **OceanWP**: https://oceanwp.org/
- **Neve**: https://themeisle.com/themes/neve/
- **Divi**: https://www.elegantthemes.com/gallery/divi/
- **Hestia**: https://themeisle.com/themes/hestia/
- **Blocksy**: https://creativethemes.com/blocksy/

### Design Frameworks
- **Material Design**: https://material.io/design
- **Material Design Guidelines**: https://m2.material.io/
- **Bootstrap**: https://getbootstrap.com/
- **Bootstrap Documentation**: https://getbootstrap.com/docs/4.6/

## Support

For issues or questions:
- Report bugs: https://github.com/inverse-inc/packetfence/issues
- Documentation: https://packetfence.org/doc/
- Community: https://packetfence.org/support/community.html
