# Волки достижений: взрослая серия · 06.11.2026

По запросу владельца первая мультяшная серия заменена более серьёзной спортивной иллюстрацией. Оформление карточек сохранено. Метод: встроенный imagegen, по одному отдельному вызову на сюжет; отдельные точечные правки убирают ненужные короны. CLI/API не использовались.

Серый взрослый волк: естественная вытянутая морда, небольшие янтарные глаза, сдержанное выражение, бордово-золотая футбольная форма. Реалистичная рисованная подача; основные предметы читаются в миниатюре. У королевских сюжетов корона, у сезонного чемпиона лавр; остальные различаются предметами условия.

Первый референс — прежний `king.png` (только идентичность волка и форма, стиль заменён); остальные используют нового «Царя горы» как стилевой референс. Генерации сохранены в `$CODEX_HOME/generated_images`, выбранные исходники скопированы в игнорируемую папку `tmp/achievement-artwork-v2/sources/`. Пути ниже — локальные источники генерации, не публичные URL.

В приложении заменены 14 существующих `app/assets/images/achievements/*.webp`. Предыдущая версия доступна в Git и в [историческом описании](achievement-wolves.md). Прозрачный WebP 192×192, суммарно 226160 байт. Только техническое уменьшение с сохранением пропорций и кодирование WebP quality 0.88 через браузерный Canvas; alpha не заменяется фоном.

## Первый промпт

```text
Use case: stylized-concept. Asset: transparent achievement miniature for adult AS Roma football prediction community. Redesign the reference character, keeping only grey wolf identity and burgundy/gold football shirt. The reference is TOO childish: do not preserve baby proportions, huge round eyes, smile or cartoon paws. Create a mature athletic anthropomorphic grey wolf with natural long muzzle, small amber eyes, calm focused serious expression, adult shoulder proportions. Tasteful detailed hand-painted sports editorial illustration, crisp strong silhouette, restrained realistic shading, no thick cartoon outline, no cute chibi or Disney style, no aggression. Scene: king of the hill — waist-up wolf on a small stone summit holding a football at his hip, modest antique gold crown, commanding composed posture. Palette grey fur, offwhite muzzle, burgundy shirt #7a1732 with gold trim #f0b323. Square composition tight crop, image fills 90% of square, readable as 64px UI icon, isolated with genuine transparent background. No text, logos, watermarks, scenery or frame.
```

## Общий промпт следующих сюжетов

```text
Use case: stylized-concept. Transparent square UI achievement miniature, read at 64px. Reference image is the approved STYLE AND CHARACTER, not a composition to duplicate. Same mature athletic grey wolf, natural long muzzle, small amber eyes, adult proportions, calm serious expression, burgundy football shirt with gold trim. Refined realistic hand-painted sports editorial illustration with strong silhouette, subdued palette, no thick cartoon outline, no chibi, no smile, no baby eyes. Waist-up close composition fills 90% square. Actual transparent background, no frame, no text or logos. Change pose and props to communicate ONLY this scene: 
```

## Точечная правка короны

Для romanist, optimist, cup-master, tester, outsider:

```text
Use case: precise-object-edit. This is an existing transparent achievement miniature. Change ONLY one detail: REMOVE the gold crown from the wolf's head entirely and reconstruct natural grey fur underneath. The wolf must have a bare head with two normal ears, absolutely no crown, headwear, laurel or extra prop. Preserve every other element exactly: mature wolf identity, small amber eyes, serious expression, pose, anatomy, burgundy/gold shirt, all held props, composition, background transparency, realistic painted sports illustration style. Keep original transparent background. No new text or symbols.
```

Для five-wins и superfan применён тот же запрос на удаление только короны с дополнительным сохранением ровно пяти медалей или числа 13 на карточке. Остальные элементы и прозрачность сохранялись.

## Сюжеты и конечные файлы

### king

Файл: `app/assets/images/achievements/king.webp` — 15324 байт.

```text
Первый промпт выше.
```

Исходник: `/mnt/c/Users/Dimon/.codex/generated_images/01a1a059-fac2-7f12-b7f2-06ef0d73f59c/exec-3f78db87-1b05-46ae-a402-3c51a89223f1.png`

SHA-256 исходника: `5b512bba2a6d01d0fc79dd610ace5409459c5adbe557d2704ecdc21a0c00d9b4`

SHA-256 WebP: `680a42248169628a01690a74c1892d9304188f5b7404d7f55e6436d0d70469b1`

### romanist

Файл: `app/assets/images/achievements/romanist.webp` — 15506 байт.

```text
Accurate Rome derby prediction: wolf wearing burgundy/gold scarf holds a round tactical target in front of his chest, football precisely centered in its gold bullseye. On either side of target a small burgundy pennant and a light blue pennant communicate the rival teams. Calm focused gaze.
```

Исходник: `/mnt/c/Users/Dimon/.codex/generated_images/01a1a059-fac2-7f12-b7f2-06ef0d73f59c/exec-01ac4697-8302-450c-876c-c34c06cd54d2.png`

SHA-256 исходника: `72a21d83fdb5783f363216b91acd05309fdc85ec071d4577fcf9f01072907df3`

SHA-256 WebP: `1a61a843fc0d0906407674687afef389fef84d39d26c613dc13b49cbbd5a2d8e`

### debut

Файл: `app/assets/images/achievements/debut.webp` — 20658 байт.

```text
First entrance into elite top ten: wolf confidently steps up through a small stadium entrance arch onto an elevated platform, holding a plain gold admission medal. Small football at threshold, upward movement clear. No crown.
```

Исходник: `/mnt/c/Users/Dimon/.codex/generated_images/01a1a059-fac2-7f12-b7f2-06ef0d73f59c/exec-7a523c82-3b3d-4c08-9ce2-92d15f678bbd.png`

SHA-256 исходника: `a907b245a910859b4f2d93c11650bdab8b89b78e23854fe830ccf2c09edc3867`

SHA-256 WebP: `e2e74689b00eef813cf4b1dd57d5b861b091099a8ff99c1252dc10bed7263cb0`

### rags-to-prince

Файл: `app/assets/images/achievements/rags-to-prince.webp` — 19856 байт.

```text
From muddy challenger to leader: wolf rises from rough muddy stone steps, worn muddy football boot visible at bottom, holding one large first-place gold medal high at chest. Burgundy shirt, a short regal burgundy cape lined gold. Determination, upward achievement.
```

Исходник: `/mnt/c/Users/Dimon/.codex/generated_images/01a1a059-fac2-7f12-b7f2-06ef0d73f59c/exec-b696525b-923d-46ef-8e93-dc9a75658e1b.png`

SHA-256 исходника: `d9f82227e29d2d379eb2f669a05f8adc78b09715b7fb754f0360db33c4319ba6`

SHA-256 WebP: `ed511f2743547ceab2a862604601d94485b3ce7e2a603cbe6495cd8a36581675`

### outsider

Файл: `app/assets/images/achievements/outsider.webp` — 18484 байт.

```text
First relegation out of elite ten: wolf in burgundy shirt looks back over one shoulder while descending a clearly visible single stone step, a small football in hand; a gold-lit open stadium gate stands behind him higher up. Composed, not crying.
```

Исходник: `/mnt/c/Users/Dimon/.codex/generated_images/01a1a059-fac2-7f12-b7f2-06ef0d73f59c/exec-4b9eb1a5-0543-46e9-a795-c1c0afd914de.png`

SHA-256 исходника: `2b4e1e9029e82a09e4d1c43afb7fe33a6061a0a117d20d5bbd0e3f592395576e`

SHA-256 WebP: `ef33612ebe00ecf2e6e902b39377643bbd477db2c98f2ff95acf8a8bedff04f2`

### optimist

Файл: `app/assets/images/achievements/optimist.webp` — 14878 байт.

```text
Unshaken belief in Roma: focused wolf holds a burgundy and gold scarf stretched across his chest, looking slightly upwards into warm early morning light. Five small footballs in an orderly arc at bottom represent the five forecasts. No sun face or thumbs up.
```

Исходник: `/mnt/c/Users/Dimon/.codex/generated_images/01a1a059-fac2-7f12-b7f2-06ef0d73f59c/exec-de38dd79-8926-43a9-80da-40e256620069.png`

SHA-256 исходника: `25c46ecdeb48ae726686ef7b0531741f2e9d1a06a4f684c9278880b49be9503e`

SHA-256 WebP: `2d355e6348511a619e38a75bf9a0529e08654717f59b66a57e448fa13134f918`

### legend

Файл: `app/assets/images/achievements/legend.webp` — 15862 байт.

```text
Season champion: dignified wolf wearing a small gold laurel wreath, both paws hold one grand golden football trophy at chest level. Strong classic victory portrait, distinguished and composed. No crown.
```

Исходник: `/mnt/c/Users/Dimon/.codex/generated_images/01a1a059-fac2-7f12-b7f2-06ef0d73f59c/exec-540d6978-2767-4c7f-abe0-185016039fe7.png`

SHA-256 исходника: `8ae4da37b721f1a95b2699a6fbd72509a888c951c5af557aa31fb53752c8c24d`

SHA-256 WebP: `b1672eb3377809b6694dc0d47b5bc3e0a7ca6cf91d39a22a70363501c5181a82`

### cup-master

Файл: `app/assets/images/achievements/cup-master.webp` — 15360 байт.

```text
European football score expert: mature wolf with a tactical football clipboard in one paw and two distinct large silver European-style football cups in front of him, one with high handles and one slender bowl. A small target drawn on the clipboard expresses precise prediction.
```

Исходник: `/mnt/c/Users/Dimon/.codex/generated_images/01a1a059-fac2-7f12-b7f2-06ef0d73f59c/exec-a4f444c5-fcc5-4465-a48a-2740d16105e8.png`

SHA-256 исходника: `ec679d9d972a549c01ec5352cd097712a948503851c81bdfba08f20292259bf0`

SHA-256 WebP: `1ec0c6f3ec0eccc0231ac33a09ca88364a424b4d242ba5b83355a3bd2b817304`

### tester

Файл: `app/assets/images/achievements/tester.webp` — 14202 байт.

```text
Forecast tester: mature wolf carefully examines a burgundy tactical clipboard with a clear checkmark and football field diagram, pencil in right paw. Thoughtful focused three-quarter pose. A single football tucked low beside him.
```

Исходник: `/mnt/c/Users/Dimon/.codex/generated_images/01a1a059-fac2-7f12-b7f2-06ef0d73f59c/exec-05d85e4b-1586-4511-965d-95ae3290bc27.png`

SHA-256 исходника: `20bc4bc10b83448a7fc79ef971a869ee08064e6d4c188bd95a108b987559255b`

SHA-256 WebP: `d60676d7fc9fdc7c4bb5cc533bdeaace043ebef63d133f885aef012650f542c3`

### head-hunter

Файл: `app/assets/images/achievements/head-hunter.webp` — 18518 байт.

```text
Three earned promotions into the elite: wolf climbs three rising stone podium steps, each step bears one plain gold star. He holds a football against his hip, looks towards the highest step. Three stars and clear upward progression are the dominant props. No weapons, binoculars, skulls or crowns.
```

Исходник: `/mnt/c/Users/Dimon/.codex/generated_images/01a1a059-fac2-7f12-b7f2-06ef0d73f59c/exec-b6f1a54d-cd25-4d11-8c8f-0c7a45c32d22.png`

SHA-256 исходника: `6e3bd0a1d2b83627682fa45074cb8b0d5440f0b58c9f23b7cd7253704efb710b`

SHA-256 WebP: `55a3cc610fe682ecb90a4c7c3e74b9198362bc08cd0257cc9daeb5a4e1610533`

### five-wins

Файл: `app/assets/images/achievements/five-wins.webp` — 14624 байт.

```text
Five first-place match victories: wolf proudly holds a horizontal dark burgundy ribbon showing EXACTLY FIVE distinct large gold winner medals in one row across his chest, a small football embossed on each. No additional medals or stars.
```

Исходник: `/mnt/c/Users/Dimon/.codex/generated_images/01a1a059-fac2-7f12-b7f2-06ef0d73f59c/exec-03caa266-8da8-45ea-b0df-b9780dbddc04.png`

SHA-256 исходника: `a3833a2b13458ece72ed55543bb6d4d05195e8ebb73166b8359533a9b63d3818`

SHA-256 WebP: `0f070fedd0abe25a8e5de57e96362efbf2aa3aa4ef02988c183edb72b0409cab`

### superfan

Файл: `app/assets/images/achievements/superfan.webp` — 14066 байт.

```text
Loyal to one football player: wolf holds a large football player collectible card with a plain faceless player bust silhouette; a separate prominent gold usage counter tab on the card reads exactly "13". One card, one player, number13 as usage counter. No other text, no hearts, no logos.
```

Исходник: `/mnt/c/Users/Dimon/.codex/generated_images/01a1a059-fac2-7f12-b7f2-06ef0d73f59c/exec-35873d05-a69e-4e7c-8ef6-07d691114afd.png`

SHA-256 исходника: `fbd966fdfc303c617dba7b9205f55d856699603f953436c2f9c1f1d01872efc2`

SHA-256 WebP: `e256a336505e415744affcb427023a194f0829237692d3d5bdbd621694d6d21c`

### general

Файл: `app/assets/images/achievements/general.webp` — 13040 байт.

```text
Neutral football participant: a composed mature wolf in burgundy/gold football shirt holds one football with both paws at waist, no achievement-specific prop or crown.
```

Исходник: `/mnt/c/Users/Dimon/.codex/generated_images/01a1a059-fac2-7f12-b7f2-06ef0d73f59c/exec-16fb6e20-9182-4a9d-9275-5e903f7a6b66.png`

SHA-256 исходника: `44497c79ac1a8d61883153ead48ec8924cd1d3157bcb57c34afb527637bda3c6`

SHA-256 WebP: `541dcaf8d0dbcfc1f2e9454bf90b5fb173edce38b0d96b93ad6f80251d90b276`

### mystery

Файл: `app/assets/images/achievements/mystery.webp` — 15782 байт.

```text
Unrevealed achievement: same mature grey wolf has a simple dark burgundy hood with gold trim and holds one plain gold closed padlock at chest level. Calm mysterious expression, small natural amber eyes. No football-specific condition props and no crown.
```

Исходник: `/mnt/c/Users/Dimon/.codex/generated_images/01a1a059-fac2-7f12-b7f2-06ef0d73f59c/exec-4bf0fa21-1d30-4492-8e0f-c148588c78fe.png`

SHA-256 исходника: `0b8ab0a5937293f0a810799e01d5c6512809feebdf6d033a226259beb43777ac`

SHA-256 WebP: `660844394a24d09122261a424dbce0d53e1831f74a5e30bf6ec448cae472ce8b`
