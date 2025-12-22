# Установка и настройка iptables

iptables-package:
  pkg.installed:
    - name: iptables

# Загрузка правил iptables и сохранение
include:
  - iptables.rules
  - iptables.save

