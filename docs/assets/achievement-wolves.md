# Миниатюры достижений AS Roma

Созданы 06.11.2026 встроенным инструментом `imagegen` по запросу владельца. Первый рисунок использует предоставленную фотографию маскота Ромы как референс персонажа; остальные используют полученный рисунок «Царь горы» как референс единого стиля. Фотография пользователя в репозиторий не включена.

Финальные ассеты: `app/assets/images/achievements/*.webp`, 192×192 px с прозрачностью. PNG-исходники скопированы в локальный игнорируемый каталог `tmp/achievement-artwork/sources/`; дополнительно оригиналы сохранены стандартным imagegen. Веб-версии подготовлены изменением размера и кодированием браузерным Canvas, без перерисовки.

| Файл | Достижение / назначение | Размер, байт |
| --- | --- | --- |
| `king.webp` | Царь горы | 11914 |
| `romanist.webp` | Романист | 12916 |
| `debut.webp` | Дебютант | 15118 |
| `rags-to-prince.webp` | Из грязи в князи | 10828 |
| `outsider.webp` | Чужой среди своих | 15036 |
| `optimist.webp` | Оптимист | 13248 |
| `legend.webp` | Легенда | 11410 |
| `cup-master.webp` | Главный по чашечкам | 13366 |
| `tester.webp` | Тестировщик | 11532 |
| `head-hunter.webp` | Охотник за головами | 12012 |
| `five-wins.webp` | Тыж Прогнозист | 10834 |
| `superfan.webp` | Персофан | 12778 |
| `general.webp` | Общая миниатюра для пользовательских ачивок | 10990 |
| `mystery.webp` | Нераскрытая секретная ачивка | 10974 |

Весь набор: **172956 байт**. В интерфейсе выводится в размере 60–72 CSS px, загружается лениво; размеры зарезервированы в HTML/CSS. Секретные условия до раскрытия используют только `mystery.webp`, независимо от реального правила и факта получения.

## Промпты

Общий промпт для всех иллюстраций после «Царя горы»:

```text
Use case: illustration-story. Create ONE separate transparent miniature achievement sticker for the AS Roma football prediction app. The reference is STYLE AND CHARACTER ONLY: match this exact friendly grey wolf with white muzzle/cheeks, huge golden-yellow eyes, black nose, burgundy football shirt with gold collar. Same premium 2D cartoon family, rounded burgundy outlines, simple cel shading. Do NOT retain its crown, hill or football unless requested below. Not a photograph. No text, numbers, lettering, sponsor logos, badges, outer frame, scenery or drop shadow. Keep one clear silhouette, recognisable at 64x64 CSS pixels, very few large props. Square composition, consistent 12% transparent padding on every side. Background genuinely transparent. Full subject and props must fit. 
```

Для первого рисунка ниже приведён полный отдельный промпт. Для остальных к общему промпту добавлялось `Achievement scene: ` и соответствующий сюжет:

### Царь горы

```text
Use case: illustration-story. Create ONE production-ready miniature achievement illustration for an AS Roma football predictions app. Use the attached photo only as reference for the wolf mascot: friendly grey wolf, fluffy white cheeks and muzzle, black nose, very large warm golden-yellow eyes, tufted ears, warm approachable smile. Draw a clean premium 2D cartoon sticker, confident rounded dark burgundy outlines, restrained soft cel shading, grey/white fur, AS Roma burgundy football shirt with gold collar and trim. No sponsors, no writing, no fake logos, no other characters, no photograph. This image represents 'King of the Hill': the wolf proudly wears a small golden crown and stands on a tiny rounded grassy hill, one paw beside a football. Head and crown prominent, pose readable at 64x64 pixels, a single clear silhouette, cheerful rather than fierce. Square composition; mascot and all props centered with 12% transparent padding on EVERY side. Transparent background, no scenery, no outer badge shape, no tile frame, no drop shadow. This will be the visual style reference for a coherent series of achievement miniatures. Do not include children or people from the source photo. Output a single square transparent PNG illustration.
```

### Романист

```text
Club-loyal derby fan: the wolf joyfully holds a burgundy-and-gold football scarf stretched above its head, a small golden heart next to its cheek. Waist-up close composition. No crown, no hill.
```

### Дебютант

```text
Debut achievement: the eager wolf steps confidently forward through a small open burgundy-and-gold stadium arch, a single gold welcome star above the arch. Dynamic welcoming pose, face prominent. No crown, no hill.
```

### Из грязи в князи

```text
From rags to riches: the smiling wolf wears a small burgundy royal cape trimmed in gold over the shirt, muddy boots below, and proudly holds a single gold medal at its chest. Face and medal prominent. No crown, no hill.
```

### Чужой среди своих

```text
Out of the top group: the friendly wolf in its burgundy shirt stands just outside a small open stadium gate, looks back over one shoulder with a wry but warm smile, holding its burgundy-and-gold scarf. The gate is a simple small prop, no scene. No crown, no hill.
```

### Оптимист

```text
Optimist achievement: a beaming wolf gives two enthusiastic thumbs up; one simple little golden sun beside its head. Waist-up close composition, joyous hopeful expression. No crown, no hill.
```

### Легенда

```text
Season legend: the proud friendly wolf wears a simple golden laurel wreath and holds ONE large golden football trophy against its burgundy shirt. Noble yet warm expression, waist-up. No crown, no hill.
```

### Главный по чашечкам

```text
European cup specialist: the friendly wolf proudly holds TWO different silver football cups, one taller with two large handles and one slim. Clear two-cup silhouette, face prominent. No crown, no hill, no logos on trophies.
```

### Тестировщик

```text
Tester achievement: the attentive friendly wolf holds a simple cream clipboard with a single large golden checkmark and a small burgundy pencil. No writing on clipboard. Thoughtful warm smile. Waist-up composition. No crown, no hill.
```

### Охотник за головами

```text
Three successful promotions achievement: the friendly sports wolf looks through a small pair of binoculars, following one floating golden star beside its head. Adventurous determined smile, waist-up. A football scouting motif, no weapons, no human heads, no violence. No crown, no hill.
```

### Тыж Прогнозист

```text
Five match victories achievement: the smiling wolf proudly fans FIVE small golden winner medals in its two paws at chest level, the five simple gold medal discs clearly separated. Waist-up, face prominent. No text or numerals, no trophy, no crown, no hill.
```

### Персофан

```text
Favourite player superfan achievement: the delighted wolf hugs one large cream collectible football player card to its chest. The card has only a simple burgundy football jersey silhouette, a golden star and a small heart; absolutely no text or numerals. Waist-up. No crown, no hill.
```

### Общая миниатюра для пользовательских ачивок

```text
General achievement placeholder: a friendly wolf in the same burgundy-and-gold shirt cradles one simple football and smiles, waist-up close composition. No crown, no hill, no extra symbols. This is a neutral fallback for custom achievements.
```

### Нераскрытая секретная ачивка

```text
Unrevealed secret achievement: the SAME friendly grey wolf wears a simple burgundy hood and holds ONE golden padlock at chest level. Warm inquisitive golden eyes, no scary expression. No condition-specific props, no numbers, no writing, no question mark, no crown, no hill. A neutral mystery silhouette that cannot reveal any particular achievement condition.
```

Первый рисунок дополнительно задавал персонажа прямо по фотографии: дружелюбный серый волк с белыми щеками, большими золотистыми глазами и бордовой футбольной формой с золотой отделкой; чистая 2D-иллюстрация, прозрачный квадратный фон, без надписей и спонсорских логотипов. Все последующие промпты заданы выше полностью.

## Контроль ассетов

| Файл | SHA-256 WebP | SHA-256 PNG-исходника |
| --- | --- | --- |
| `king.webp` | `b18a96ea37278f92efffb6197cc839c234ad3d9c6e52e52ca2788b4d12d1f36c` | `1e98e523689c421f77bff1d96760af49c84bc823d427fbbca821c7270e308614` |
| `romanist.webp` | `246fdb1c18fa9b397ab2b1990f69603b11ffb79a54278af27e086fcd97ac5114` | `4641f9376a8fe6b609e9dac5645b2e99f57427d5779649e0780bf6500f6c4c45` |
| `debut.webp` | `d1e523b1cd16e7a8089c839c23fc99e41a997dcbdf591eaac1e5f5f421a865d7` | `4aa9784dbcdba1fbfe6135fdd4f1ccc3568e7dcdba25044528ebdb7854897c35` |
| `rags-to-prince.webp` | `1c6ba0a8cb93c42cf81276ea63d63427dfb5fae4b7a74dc396a71dad6534d145` | `e8e45c72be2b884bfa06f72a534950f2696bc86ec418be8758d21046a3a60555` |
| `outsider.webp` | `7a111a25656c30ce113d3f05baa61cd04c19bd908cc15f173fb68d74e2e59ae7` | `3ec26eaaae4f6bf484f1cc7dcd38bb87ed641c917ce64e2ba3c612cae0db5bb3` |
| `optimist.webp` | `71ddfab79f4e4c6c4cd36fae3b1bcb68710d9d88477a69e6fe12bdf460f88f7a` | `31ef9633a62cb1464a2d9781eebbd1078caa819c71abb2e4308967d1c8ef4b28` |
| `legend.webp` | `2e64e06f78d33122407a05a1a8ac4f064567a76578aa2eb9ea5f6c62ee5f5c4d` | `206c589b1bf4eca734c63ff00e2caf0076fd073b18e934887ce1153fbd572462` |
| `cup-master.webp` | `0f7b0ad964df556e25f9ea5716e36ad7717a8dd85f7b55415750285588a04e06` | `0046be87af165644db0f14fb500974aca3b35daffdd314555377876b04b89ed3` |
| `tester.webp` | `7e9250f510817a147a64ac43cae7fa270be28370e5513548fbe76957082d7251` | `8177730210abdd410591d106c37b5526fd6cb9e04182bea9a637006c10596993` |
| `head-hunter.webp` | `c49b5118b40e0238ad676a59d47f3753174fa95c1ec5486dcbad75981bb67a16` | `3426624bc8c58a613e539b080b97434bd5617c7f99331f576fd21291c529b1d4` |
| `five-wins.webp` | `7e5cc54568bf7c183dbac982be5e1baeb3daa9904afc859fefcc2794d07dc82d` | `1d9f4ccc36cde84dc32f6e930396174e7b2cb4cb47ef79eccc73aaf8ff8e9fcd` |
| `superfan.webp` | `e3de3b3f6f30b779412be7944606e817294c7b8f06f1f368f9c29f41ee4aef6e` | `0955d1246c528b9f1b64817a2c8e1e816d865f6134b5def669704ef9f675ca0f` |
| `general.webp` | `e3401f42e0c4cba400651a2a6d5cd1667abdbf83f806d3fc3f0c3cb5aa060f5c` | `2db4c32031476253947e9e2950aa13becd491cea313c59ed46efd09f3b3c214a` |
| `mystery.webp` | `1abb1eb26d357dd68efc6ccfb7eadcb5ae6f6207cb00cf5d131aab76e99bb38b` | `b40c1161e79441d3b807a0d312cbbfd7f9e059ad6a5bd47d0b70068eaa647deb` |
