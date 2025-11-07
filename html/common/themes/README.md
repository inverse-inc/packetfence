# Captive Portal CSS Themes

This directory contains CSS theme files for the PacketFence captive portal. Themes allow you to customize the look and feel of the portal based on different venue types.

## Available Themes

1. **default** - Standard PacketFence color scheme (red/blue)
2. **hotel** - Elegant gold and navy blue tones
3. **restaurant** - Warm red and brown tones
4. **sport-event** - Energetic orange and blue
5. **fastfood** - Bright red and yellow
6. **university** - Academic burgundy and deep blue
7. **retail** - Modern teal and coral
8. **home** - Cozy green and warm beige

## Configuration

To set a CSS theme for a connection profile:

1. Edit `/usr/local/pf/conf/profiles.conf`
2. Add or modify the `portal_css_theme` parameter for your profile:

```ini
[my_hotel_profile]
description=Hotel WiFi
portal_css_theme=hotel
sources=my_auth_source
...
```

3. Restart pfconfig and httpd.portal services:
```bash
/usr/local/pf/bin/pfcmd configreload hard
/usr/local/pf/bin/pfcmd service httpd.portal restart
```

## Theme Values

Use one of these values for the `portal_css_theme` parameter:

- `default` - Default PacketFence theme
- `hotel` - Hotel theme
- `restaurant` - Restaurant theme
- `sport-event` - Sport event theme
- `fastfood` - Fast food theme
- `university` - University theme
- `retail` - Retail theme
- `home` - Home theme

## Creating Custom Themes

To create a custom theme:

1. Create a new CSS file in this directory (e.g., `custom.css`)
2. Override the color variables and styles as needed:

```css
/**
 * Custom Theme
 * Description of your theme
 */

/* Background colors */
html { background-color: #yourcolor !important; }
header { background-color: #yourcolor !important; }

/* Primary button colors */
.c-btn--primary, a.c-btn--primary {
  background-color: #yourcolor !important;
}

/* Add more overrides as needed */
```

3. Set `portal_css_theme=custom` in your connection profile

## Theme Components

Each theme overrides these key elements:

- **Background colors** - Page and header background
- **Primary colors** - Main action buttons
- **Secondary colors** - Secondary buttons and icons
- **Link colors** - Text links throughout the portal
- **Input styling** - Form input borders and labels
- **Notification colors** - Success and error messages

## Color Scheme Reference

### Hotel Theme
- Primary: Gold (#d4af37)
- Secondary: Navy Blue (#1e3a5f)
- Background: Cream (#f5f3ed)

### Restaurant Theme
- Primary: Warm Red (#c1440e)
- Secondary: Brown (#6b4423)
- Background: Warm Cream (#fdf8f3)

### Sport Event Theme
- Primary: Orange (#ff6b35)
- Secondary: Blue (#004e89)
- Background: Light Blue (#f0f4f8)

### Fast Food Theme
- Primary: Red (#e63946)
- Secondary: Yellow (#f4a127)
- Background: Light Yellow (#fff8e7)

### University Theme
- Primary: Burgundy (#8b1538)
- Secondary: Deep Blue (#003366)
- Background: Light Gray (#f4f4f6)

### Retail Theme
- Primary: Teal (#00bfa5)
- Secondary: Coral (#ff6b6b)
- Background: Light Gray (#f8f9fa)

### Home Theme
- Primary: Soft Green (#6a994e)
- Secondary: Warm Brown (#a67c52)
- Background: Warm Beige (#faf8f3)

## Notes

- The `default` theme doesn't apply any overrides
- All themes use `!important` to ensure they override the base styles
- Themes are loaded after the main `styles.css` file
- Changes to theme files are immediately visible (no compilation needed)
