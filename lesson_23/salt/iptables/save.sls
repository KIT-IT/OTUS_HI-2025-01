# Сохранение правил iptables

# Установка iptables-persistent для сохранения правил
iptables-persistent-package:
  pkg.installed:
    - name: iptables-persistent
    - install_recommends: False

# Сохранение правил
iptables-save-rules:
  cmd.run:
    - name: netfilter-persistent save
    - require:
      - pkg: iptables-persistent-package
    - onchanges:
      - cmd: iptables-flush
      - cmd: iptables-default-policy
      - cmd: iptables-allow-loopback
      - cmd: iptables-allow-established
      - cmd: iptables-allow-ssh

# Включение автоматической загрузки правил при загрузке
iptables-persistent-service:
  service.running:
    - name: netfilter-persistent
    - enable: True
    - require:
      - pkg: iptables-persistent-package

