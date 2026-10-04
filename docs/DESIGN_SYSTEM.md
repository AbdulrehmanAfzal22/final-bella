# Maison Élan Design Foundation

This is an opt-in visual foundation. Existing pages keep their current markup and behavior; new or later-migrated UI can use the namespaced `me-` component classes and common React primitives.

## Structure

```text
src/
  components/common/
    Animation.jsx
    Badge.jsx
    Button.jsx
    CardFoundations.jsx
    Checkbox.jsx
    Container.jsx
    Divider.jsx
    EmptyState.jsx
    IconButton.jsx
    Input.jsx
    Loader.jsx
    Modal.jsx
    SectionTitle.jsx
    Select.jsx
    Textarea.jsx
    index.js
  styles/
    tokens.css
    theme.css
```

`tokens.css` is imported by the existing base stylesheet and defines the palette, typography, spacing, radii, shadows, motion and breakpoint values. Its legacy variable aliases (`--ink`, `--paper`, `--line`, `--accent`, `--sans`, `--display`) preserve existing styles. `theme.css` is loaded after the existing app styles in `main.jsx`; its rules are scoped under `.me-` classes so existing pages are not restyled until they opt in.

Fonts use the existing Italiana display and DM Sans body faces loaded by `index.html`. Responsive type tokens switch at 768px, 1024px and 1440px; base values support 320px mobile widths. Spacing tokens are 4, 8, 12, 16, 24, 32, 48, 64, 96 and 128px.

## Usage

```jsx
import {Button, Container, Input, SectionTitle} from '../components/common';

<Container width="narrow">
  <SectionTitle eyebrow="Your wardrobe" title="Saved pieces" />
  <Input label="Email address" type="email" autoComplete="email" required />
  <Button variant="primary" type="submit" loading={saving}>Save</Button>
</Container>
```

Use `variant="primary|secondary|outline|text"` for the new button system. Omitting `variant` preserves the existing `.button` API and appearance. `Loader` and `EmptyState` likewise retain their legacy default; pass `variant="premium"` to opt into the new treatment. Existing modal usages that provide a `className` keep their existing styles.

`Input`, `Select`, `Textarea` and `Checkbox` accept `label`, `hint`, and `error`; they connect descriptions and set `aria-invalid`. Card foundations are `ProductCardFoundation`, `CollectionCardFoundation`, and `ContentCardFoundation`. `Animation` accepts `fadeIn`, `fadeUp`, `slideIn`, or `imageReveal`; all motion has a reduced-motion override.

## Accessibility and Motion

Controls have visible keyboard focus, disabled and invalid states. Icon buttons require a human-readable `label`. Images receive alt text from callers. Feedback components use status semantics. Motion durations range from 200–460ms for controls/reveals; image reveal is 700ms and is disabled under `prefers-reduced-motion`.

Bronze is used as an accent, not as small body copy; muted text uses the charcoal-gray token. Shadows are low-opacity, with restrained 4px image/card radii. No new UI dependencies or external fonts were added.