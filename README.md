# Obscure SDDM Theme

A minimal yet customizable SDDM theme that uses IPA (International Phonetic Alphabet) characters for password masking, creating an obscure and unique look for your login experience.

![demo](https://github.com/user-attachments/assets/f4a04b3e-955f-4936-b195-c92ac4e7cf66)

## Features

- Clean look-and-feel driven by a accent colors and glass tint controls
- Unique IPA character-based password masking with optional randomized output
- Built-in password visibility toggle with animated error feedback
- Customizable background image with blur, tint color, and intensity controls
- Keyboard-driven user/session selectors styled with circular accent buttons

## Requirements

- SDDM >= 0.19.0
- Qt >= 6.0.0
- A system font that supports IPA characters (default: Inter)

## Installation

### Manual Installation

1. Clone this repository:

   ```bash
   git clone https://github.com/saatvik333/obscure-sddm-theme.git
   ```

2. Install necessary packages

   ```bash
   yay -S sddm qt6-5compat
   ```

3. Copy the theme to SDDM themes directory:

   ```bash
   sudo cp -r obscure-sddm-theme /usr/share/sddm/themes/obscure
   ```

4. Set the theme in SDDM configuration:

   ```bash
   sudo sh -c 'printf "[Theme]\nCurrent=obscure\n" > /etc/sddm.conf'
   ```

### Using Package Managers

Coming soon...

## Configuration

The theme can be customized through the `theme.conf` file. Here are the available options:

All customization lives in `theme.conf`. Settings are grouped just like in the file to keep things easy to reason about.

### Palette

| Key | Description | Default |
| --- | --- | --- |
| `textColor` | Primary foreground/text color | `#cdd6f4` |
| `errorColor` | Accent used for error flashes | `#f38ba8` |
| `backgroundColor` | Base fill behind the glass layer | `#1e1e2e` |

### Background

| Key | Description | Default |
| --- | --- | --- |
| `backgroundImage` | Path to an optional wallpaper (leave empty for solid color) | _(empty)_ |
| `backgroundFillMode` | Image sizing mode (`aspectCrop`, `aspectFit`, `stretch`, `tile`, `center`) | `aspectCrop` |
| `backgroundOpacity` | Opacity of the background image layer | `1` |
| `backgroundGlassEnabled` | Enable the Gaussian blur glass treatment | `false` |
| `backgroundGlassIntensity` | Blur strength (0–64) | `64` |
| `backgroundTintColor` | Base tint color placed over the wallpaper | `#11111b` |
| `backgroundTintIntensity` | Tint opacity (0–1) | `0` |

### Typography

| Key | Description | Default |
| --- | --- | --- |
| `fontFamily` | UI font family | `Inter` |
| `baseFontSize` | Base font size in pixels | `15` |

### Controls & Behaviour

| Key | Description | Default |
| --- | --- | --- |
| `controlCornerRadius` | Corner radius for inputs, selectors, and power buttons | `30` |
| `controlAccentColor` | Single accent color driving button fills/borders | `#89b4fa` |
| `controlOpacity` | Base opacity controlling control fill/border strength | `0.3` |
| `allowEmptyPassword` | Permit logging in without a password | `false` |
| `showUserSelector` | Show user selection carousel by default | `false` |
| `showSessionSelector` | Show session selection carousel by default | `false` |
| `randomizePasswordMask` | Shuffle IPA mask characters each keystroke | `true` |
| `animationDuration` | Base animation length in milliseconds | `320` |
| `passwordFlashLoops` | How many times the password field flashes on error | `3` |
| `passwordFlashOnDuration` | Duration of each flash highlight (ms) | `200` |
| `passwordFlashOffDuration` | Duration of the fade-out between flashes (ms) | `260` |

The password visibility toggle honours all these settings automatically—no extra configuration required.

## Shortcuts

The theme provides several keyboard shortcuts for quick access to various functions:

- `F1`: Toggle help text display
- `F2` or `Alt+U`: Toggle user selector
- `Ctrl+F2` or `Alt+Ctrl+U`: Switch to previous user
- `F3` or `Alt+S`: Toggle session selector
- `Ctrl+F3` or `Alt+Ctrl+S`: Switch to previous session
- `F10`: Suspend system (if available)
- `F11`: Shutdown system (if available)
- `F12`: Reboot system (if available)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by various SDDM themes in the community
- IPA characters sourced from standard Unicode specifications

## Support

If you like this theme, consider:

- Starring the repository
- Reporting bugs
- Contributing to the code
- Sharing it with others :)
