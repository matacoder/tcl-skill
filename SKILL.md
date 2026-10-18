---
name: tcl-tv
description: Обслуживание телевизоров TCL на Google TV / Android TV 11 (BeyondTV, Realtek) по ADB с Mac — подключиться по сети, сделать Projectivy (или другой сторонний лаунчер) домашним экраном так, чтобы не слетал после перезагрузки, найти и отключить телеметрию/рекламу TCL, ускорить интерфейс. Использовать, когда пользователь говорит «телевизор TCL», «тв», «лаунчер слетает», «Projectivy», «Google TV тормозит», «шпионские процессы в телевизоре», даёт IP телевизора или говорит, что включил режим разработчика.
---

# TCL Google TV по ADB: лаунчер, телеметрия, ускорение

Проверено 2026-10-18 на TCL Smart TV Pro (product `G03_4K_GB`, device `BeyondTV4`), Android TV 11
(`RP1A.200622.001`), прошивка `V8-R51MT05-LF1V652`, 2 ГБ ОЗУ, 4 ядра, Projectivy 4.72.

## Правила

- Только `pm disable-user --user 0` / `pm enable` — ничего не удалять, не трогать uid `system`-пакеты,
  от которых зависит ТВ (`com.tcl.tv`, `com.tcl.ttvs`, `com.tcl.tvinput`, `com.tcl.guard`, `com.tcl.dashboard`).
- Перед отключением показать пользователю список и что перестанет работать; после — перезагрузить
  и проверить, что прошивка не включила обратно.
- Экран ТВ смотреть через `adb exec-out screencap -p > s.png`, управлять — `adb shell input keyevent`
  (`DPAD_UP/DOWN/LEFT/RIGHT/CENTER`, `BACK`, `HOME`), тексты экрана — `uiautomator dump`.

## 1. Подключение с Mac

На ТВ: Настройки → Об устройстве → 7 раз «Сборка ОС» → Для разработчиков → «Отладка по USB».
ADB по сети слушает `<tv-ip>:5555` (проверка: `nc -zv <tv-ip> 5555`).

Грабли на macOS:

1. **adb из Homebrew зависает** на любой команде, даже `adb version` — карантин Gatekeeper
   (`xattr -l` показывает `com.apple.quarantine`). Брать adb из Android SDK
   (`~/Library/Android/sdk/platform-tools/adb`) или снять карантин с разрешения пользователя.
2. **«Локальная сеть» macOS не пускает adb в LAN**: `failed to connect ... No route to host`,
   при этом `nc` до порта проходит. Обход без смены настроек — проброс через системный `nc`:
   ```sh
   nohup scripts/adb-relay.sh <tv-ip> >/dev/null 2>&1 &
   adb connect 127.0.0.1:15555
   export ANDROID_SERIAL=127.0.0.1:15555
   ```
   Альтернатива — разрешить терминалу «Локальная сеть» в Конфиденциальности.
3. В песочнице Claude Code adb-сервер не поднимается — команды adb запускать без песочницы.
4. Первое подключение → `unauthorized`: попросить пользователя нажать на ТВ «Всегда разрешать
   с этого компьютера» → OK.
5. `adb reboot` рвёт проброс — после загрузки (~90 с) `adb disconnect; adb connect 127.0.0.1:15555`.

## 2. Сторонний лаунчер слетает после перезагрузки

Диагностика:
```sh
adb shell pm query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME
adb shell appops get <launcher-pkg> APP_AUTO_START
adb shell dumpsys accessibility | grep -E "Bound services|Enabled services"
adb shell logcat -d | grep TclAppBoot | grep <launcher-pkg>
```

Картина: Google TV Home (`com.google.android.apps.tv.launcherx`) имеет HOME-приоритет 2, Projectivy — 0.
Projectivy перехватывает HOME через свою службу спецвозможностей, но после загрузки служба
«Enabled», а «Bound services» пусто, в логе:
`TclAppBoot ... isAllow = 'false', reason = 'callee_does't_have_OP_AUTO_START_permission.'`

**Не работает** — прошивка TCL откатывает при каждой загрузке:
- `pm disable-user com.google.android.apps.tv.launcherx` — снова включён;
- `appops set <pkg> APP_AUTO_START allow` — снова `ignore`.

**Работает** — разрешить автозапуск через TCL Guard (сохраняется):
```sh
adb shell am start -a com.tcl.guard.action.PermissionManager
```
«Фильтр разрешений» → «Разрешение на Автоматический запуск» → «Авто-менеджер» стрелкой в
**Закрытый** (пока он «Открытый», у всех приложений «В автоматическом управлении» и менять нельзя) →
у лаунчера стрелкой **Открытый**. Остальные приложения остаются «Закрытый».
Навигация с ADB: `DPAD_CENTER` (войти), `DPAD_UP` + `DPAD_RIGHT` (авто-менеджер),
`DPAD_DOWN` + `DPAD_RIGHT` (первое приложение в списке). Проверять скриншотом.

В самом Projectivy должна быть включена служба спецвозможностей (перехват HOME).

Проверка после `adb reboot`:
```sh
adb shell appops get com.spocky.projengmenu APP_AUTO_START   # Uid mode: allow
adb shell dumpsys accessibility | grep "Bound services"      # есть Projectivy
adb shell dumpsys activity activities | grep -m1 mResumedActivity
```

## 3. Телеметрия TCL

Что найдено:
- `com.tcl.bi` (`BiReportService`, модуль `usagest`) — статистика использования приложений;
  `com.tcl.ttvs` шлёт в него события каждые 20–60 с (`bi.com.tcl.bi.DataReport` в logcat).
- Постоянные TCP-соединения системных процессов TCL к Alibaba Cloud (`8.209.x.x:6179`,
  `8.211.x.x:6177`) — push/реклама TCL; пропадают после отключения пакетов ниже.
- Работает даже при отказе в соглашении (`settings get global userAgreementCheckboxShareDiagnostics` = 0).

Как смотреть самому:
```sh
adb shell netstat -tn | grep ESTAB                  # внешние соединения
adb shell cat /proc/net/tcp6                        # колонка uid → pm list packages -U | grep uid:<n>
adb shell dumpsys activity services | grep "ServiceRecord.*com.tcl"
adb shell logcat -d -b all | grep -iE "tcl.bi|DataReport|upload"
```
У пакетов с uid 1000 разрешения общие с системой — по `dumpsys package` их не различить.

## 4. Ускорение

Типично: через 5 мин после старта свободно ~90 МБ из 2 ГБ, своп ~240 МБ, load average ~28.
Главные потребители: лаунчер, GMS, Google TV Home (два процесса, ~55 МБ — не отключить, см. выше),
Ассистент `katniss` (~70 МБ и CPU), витрины/реклама/аккаунт TCL.

`scripts/debloat.sh [status|disable|enable]` — отключает телеметрию/рекламу TCL и неиспользуемые
сервисы (список в скрипте); `VOICE=1` добавляет Ассистент (`katniss`) — после этого не работают
кнопка микрофона и голосовой поиск. Отключённые так пакеты прошивка после перезагрузки **не** включает.
Сознательно не трогать: Netflix/Prime (могут быть нужны), `com.tcl.ttvs` (каст/мультискрин),
`com.tcl.guard` (автозапуск лаунчера), `com.tcl.dashboard` (быстрые настройки).

Анимации (сохраняются):
```sh
adb shell 'for k in window_animation_scale transition_animation_scale animator_duration_scale; do settings put global $k 0.5; done'
```

Откат: `scripts/debloat.sh enable`, анимации — `settings put global <key> 1.0`.
