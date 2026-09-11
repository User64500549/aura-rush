# Brand assets — «Стиль-рейд»

Готовые изображения для страницы опыта. Они намеренно не подключены к `ImageLabel`
через выдуманный `rbxassetid`: сначала загрузите файлы в Creator Dashboard, дождитесь
модерации и только затем занесите реальные ID в asset manifest.

| Файл | Размер | Назначение |
|---|---:|---|
| `style-raid-key-art-v1.png` | 1672×941 | широкая обложка / thumbnail |
| `style-raid-icon-v1.png` | 1254×1254 | квадратная иконка опыта |
| `style-raid-key-art-v2.png` | 1672×941 | актуальная командная обложка |
| `style-raid-icon-v2.png` | 1254×1254 | актуальная командная иконка |
| `remix-city-premium-map-concept-v3.png` | 1672×941 | environment reference для Premium City v6 |

Изображения созданы встроенным ImageGen без логотипов, водяных знаков и текста внутри
изображения. Название лучше накладывать в Creator Dashboard или в отдельном
проверяемом графическом слое, чтобы кириллица не искажалась.

## Финальные промпты

Файл environment reference не должен автоматически загружаться в Roblox как
runtime texture без отдельной проверки и модерации.

### Premium City — environment reference v3

```text
Use case: stylized-concept
Asset type: premium Roblox environment concept art / visual target for a playable hub
Primary request: redesign AURA RUSH Remix City as a memorable premium social-fashion adventure hub built around the “Heart of Style”, a monumental sculpture of six interlocking luminous material ribbons; make the city instantly readable, original, youth-oriented and feasible to rebuild as modular Roblox geometry
Scene/backdrop: blue-hour metropolitan plaza with a broad safe arrival avenue, one central Heart landmark, a ground navigation loop, six clearly different radial districts and an elevated circular Prism Rail; district silhouettes suggest Prism Metro, Cloud Quarter, Moonlit Greenhouse, Orbital Boardwalk, Velvet Archive and Solar Cathedral
Style/medium: polished stylized 3D game environment keyframe, editorial streetwear meets music-video set design and premium city wayfinding, tactile materials, production concept rather than generic cyberpunk
Composition/framing: wide 16:9 elevated three-quarter view, strong foreground-to-heart sightline, Heart centered and visible, six districts readable around the ring, clean player-scale paths, layered foreground/midground/skyline, space for gameplay and social photo areas
Lighting/mood: aspirational, energetic and welcoming; controlled blue-hour ambience, warm windows, soft volumetric accents, emissive light only where it communicates gameplay state
Color palette: deep ink and warm milk base, restrained chrome, selective acid lime, cyan, coral, violet and warm gold; each district distinct but part of one art direction
Materials/textures: painted concrete, brushed metal, fabric ribbons, porcelain, glass ribs, velvet, paper and solar mirrors; believable stylized response and modular repetition
Constraints: no text, no logos, no watermark, no trademarks, no UI, no photoreal people, no beauty-surgery or body-rating themes; readable at thumbnail scale; paths and landmark must remain buildable and performant in Roblox
Avoid: generic neon cyberpunk, empty flat plaza, random boxes, excessive purple-pink gradient, illegible signage, clutter, fake glyphs, AI-looking pseudo-writing, unsafe narrow paths, lighting haze that hides navigation
```

### Широкая обложка

```text
Use case: stylized-concept
Asset type: Roblox experience key art / thumbnail for the current game project
Primary request: premium youth fashion-adventure key art for “AURA RUSH: СТИЛЬ-РЕЙД”, showing a team of four diverse block-stylized game avatars sprinting through a city district that physically transforms in their wake from muted ink architecture into bold editorial color, fabric ribbons, light signage and kinetic street-fashion set pieces
Scene/backdrop: layered metropolitan runway-district with readable foreground, midground and skyline; before/after transformation visibly travels from left to right
Subject: four original block-stylized multiplayer avatars wearing creative color-and-material outfits, energetic but friendly, focused on style, teamwork and movement rather than beauty standards
Style/medium: polished AAA game key art, stylized 3D render, fashion editorial meets music-video lighting and urban wayfinding, production-ready thumbnail composition
Composition/framing: wide cinematic composition, strong central silhouette, clear faces and poses at thumbnail scale, open breathing room near top center for a later title overlay
Lighting/mood: confident, playful, aspirational; dusk with crisp practical lighting and controlled volumetric accents
Color palette: deep ink, warm milk, acid lime, coral, cold blue, restrained chrome; avoid rainbow overload
Materials/textures: fabric, painted concrete, translucent acrylic, brushed metal, paper posters; tactile and believable
Constraints: no text, no logos, no trademarks, no watermark; no body-rating imagery, no photoreal humans, no beauty surgery themes, no generic cyberpunk, no excessive neon haze
Avoid: clutter, illegible tiny props, random glyphs, AI-looking pseudo-writing, purple-pink gradient overload
```

### Квадратная иконка

```text
Use case: stylized-concept
Asset type: square Roblox experience icon for the current game project
Primary request: iconic close-up of three original block-stylized fashion-adventure avatars bursting through a diagonal transition from monochrome ink city to vivid transformed street runway, communicating teamwork, motion and style at very small size
Scene/backdrop: simplified city-wayfinding shapes and one sweeping fabric ribbon, no tiny environment detail
Subject: three friendly expressive block-stylized multiplayer avatars with distinct outfits using acid lime, coral and cold blue accents
Style/medium: premium stylized 3D game icon, tactile fashion editorial, bold clean silhouettes, store-ready polish
Composition/framing: square, tight centered group, faces and upper bodies readable at 128px, strong diagonal before/after split, safe margins
Lighting/mood: bright, confident, playful, crisp rim light
Color palette: deep ink, warm milk, acid lime, coral, cold blue, restrained chrome
Materials/textures: fabric, matte painted surfaces, brushed metal accents
Constraints: no text, no logos, no trademarks, no watermark, no body-rating or beauty-surgery themes, no generic cyberpunk, no purple-pink gradient overload
Avoid: clutter, random symbols, pseudo-writing, extra limbs, cropped faces
```
