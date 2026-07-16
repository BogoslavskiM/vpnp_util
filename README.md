# vpnp_util

`vpnp_util` позволяет оставить весь компьютер в обычной сети или на общем VPN, а выбранный браузер или выбранный терминал запускать через VPN из указанного WireGuard-конфига.

Утилита поднимает локальный SOCKS-прокси через WireGuard-конфиг и дает удобную глобальную команду `vpnp`.

Проект рассчитан на macOS. Внутри используется `sing-box` и `launchctl`.

## Быстрый старт после клона

```zsh
cd vpnp_util
./install
vpnp update-config /path/to/wireguard.conf
vpnp up
vpnp status
```

После этого можно запускать браузер или терминал через VPN-прокси:

```zsh
vpnp google
vpnp yandex
vpnp shell
```

## Требования

Нужен установленный `sing-box`.

```zsh
brew install sing-box
```

Также нужен WireGuard-конфиг. Обычно это файл `*.conf`.

## Установка глобальной команды

Из папки проекта:

```zsh
./install
```

Скрипт создает глобальную команду `vpnp` через symlink в подходящую директорию из `PATH`, например:

```text
/usr/local/bin/vpnp -> /path/to/vpnp_util/vpnp
```

Проверка:

```zsh
vpnp help
```

Если установка не смогла записать symlink, можно указать другую директорию:

```zsh
VPN_INSTALL_BIN_DIR="$HOME/.local/bin" ./install
```

Или установить в `/usr/local/bin` с правами администратора:

```zsh
sudo VPN_INSTALL_BIN_DIR=/usr/local/bin ./install
```

## Настройка VPN-конфига

Команда:

```zsh
vpnp update-config /path/to/wireguard.conf
```

Что делает:

- проверяет, что в файле есть секции `[Interface]` и `[Peer]`;
- копирует WireGuard-конфиг внутрь проекта;
- создает/обновляет локальный `vpn.env`;
- настраивает проект на использование локальной копии конфига.

Можно передать не файл, а папку:

```zsh
vpnp update-config /path/to/config-directory/
```

В папке должен быть ровно один файл с расширением `*.conf`, `*.wg` или `*.vpn`.

## Основные команды

```zsh
vpnp up
```

Поднять локальный SOCKS-прокси через VPN.

```zsh
vpnp down
```

Остановить прокси.

```zsh
vpnp status
```

Показать состояние сервиса и локального SOCKS-порта.

```zsh
vpnp google
```

Открыть Google Chrome через VPN-прокси. Chrome запускается с обычным профилем/экраном выбора пользователя, без отдельного `user-data-dir`.

```zsh
vpnp yandex
```

Открыть Yandex Browser через VPN-прокси с обычным профилем.

```zsh
vpnp shell
```

Открыть новый shell в текущем терминале, где трафик терминальных утилит идет через VPN-прокси.

Внутри этого shell выставляются:

- `ALL_PROXY`
- `HTTP_PROXY`
- `HTTPS_PROXY`
- `GIT_SSH_COMMAND`

Это нужно, чтобы через прокси ходили `curl`, пакетные менеджеры, Git over SSH и похожие инструменты.

Чтобы выйти из VPN-shell:

```zsh
exit
```

```zsh
vpnp log
vpnp log 200
```

Показать последние строки лога `sing-box`.

```zsh
vpnp ip
```

Сравнить обычный IP и IP через прокси. Для этой команды нужно вручную задать `IP_CHECK_URL` в локальном `vpn.env`.

```zsh
vpnp uninstall
```

Удалить глобальную команду `vpnp`. Проект, конфиги и runtime-файлы не удаляются.

## Как это работает

1. `vpnp update-config` кладет WireGuard-конфиг в локальную папку проекта.
2. `vpnp up` генерирует конфиг для `sing-box`.
3. `sing-box` запускается через `launchctl` как пользовательский сервис.
4. На локальном адресе поднимается SOCKS-прокси, по умолчанию:

```text
socks5://127.0.0.1:1080
```

5. Браузерные команды (`vpnp google`, `vpnp yandex`) запускают браузер с proxy-флагами.
6. `vpnp shell` открывает shell с proxy-переменными окружения.

## Локальные файлы

Эти файлы не должны попадать в git:

- `vpn.env`
- `configs/`
- `runtime/`

Они уже добавлены в `.gitignore`.

## Типичный сценарий

Первичная настройка:

```zsh
cd vpnp_util
./install
vpnp update-config ~/Downloads/my-vpn.conf
vpnp up
```

Открыть Chrome через VPN:

```zsh
vpnp google
```

Открыть терминал через VPN:

```zsh
vpnp shell
git pull
exit
```

Остановить VPN-прокси:

```zsh
vpnp down
```

## Если что-то не работает

Проверить статус:

```zsh
vpnp status
```

Посмотреть лог:

```zsh
vpnp log 100
```

Перезапустить прокси:

```zsh
vpnp down
vpnp up
```

Обновить WireGuard-конфиг:

```zsh
vpnp update-config /path/to/new-wireguard.conf
vpnp down
vpnp up
```
