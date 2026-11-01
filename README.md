# AS Roma бот прогнозов

Rails/PWA-приложение для приёма и автоматического расчёта прогнозов на матчи AS Roma.

## Стек
- Ruby 4.0.6
- Rails 8.1
- SQLite
- ERB + Turbo + Stimulus
- Solid Queue
- PWA-каркас
- Kamal для будущего production-деплоя

Полные игровые правила: `docs/REQUIREMENTS.md`.

## Первый запуск в WSL

```bash
cd ~/code/forecast_bot
bundle install
bin/rails db:migrate
bin/rails db:seed
bin/rails server
```

Открыть: `http://localhost:3000`.

Если база development была создана раньше, но миграции ещё не запускались, дополнительных действий не нужно.

## Первый администратор

1. Зарегистрируйте обычный аккаунт через сайт.
2. Откройте консоль:

```bash
bin/rails console
```

3. Выполните:

```ruby
user = User.find_by!(nickname_key: User.nickname_key_for("ВАШ_НИК"))
user.update!(role: :admin)
```

После обновления страницы появится раздел «Админка».

## Что уже реализовано
- регистрация и вход по никнейму;
- роли user/admin;
- профиль, смена email/пароля и будущие настройки push;
- сезоны, четыре турнира, матчи и окно -48/-2 часа;
- активные/неактивные игроки;
- прогноз одной формой;
- отдельные лимиты авторов голов/ассистов;
- резервирование и расчёт ЗБ;
- временные вопросы choice/text;
- удобный ручной ввод результата матча;
- предварительный расчёт и подтверждение;
- настраиваемые значения баллов;
- текущая таблица и результаты по матчам;
- Топ-10/Претенденты;
- ручные ачивки и автоматическое начисление ЗБ за них;
- откат результатов до выбранного номера матча;
- audit log;
- PWA manifest/service worker без offline-кэша и Web Push.

## Перенос старых аккаунтов

В проекте есть rake-задачи `legacy:*`.

### Пользователи
JSON может быть объектом:

```json
{
  "nickname1": "old_codeword_1",
  "nickname2": "old_codeword_2"
}
```

Запуск:

```bash
LEGACY_USERS=/path/users.json bin/rails legacy:import_users
```

Такой аккаунт при первом входе будет обязан указать email и новый пароль.

### Определения ачивок

```bash
LEGACY_ACHIEVEMENTS=/path/achievements.json bin/rails legacy:import_achievements
```

### Уже полученные ачивки

```bash
LEGACY_USER_ACHIEVEMENTS=/path/user_achievements.json bin/rails legacy:import_user_achievements
```

При переносе старых ачивок новые ЗБ не начисляются.

## Важно
Web Push и пользовательское восстановление пароля оставлены на следующий этап. Rails-каркас для восстановления пароля сохранён, но ссылка в основном UI пока не выводится.
