# Роль для Salt Master сервера
# Устанавливает и настраивает Salt Master

include:
  - iptables

salt-master-packages:
  pkg.installed:
    - pkgs:
      - salt-master
      - salt-minion  # Minion тоже нужен для local execution

salt-master-service:
  service.running:
    - name: salt-master
    - enable: True
    - require:
      - pkg: salt-master-packages

salt-master-config:
  file.managed:
    - name: /etc/salt/master
    - source: salt://files/master.conf
    - template: jinja
    - require:
      - pkg: salt-master-packages
    - watch_in:
      - service: salt-master-service

# Создание директорий для Salt States и Pillar
salt-directories:
  file.directory:
    - names:
      - /srv/salt
      - /srv/pillar
    - makedirs: True
    - mode: 755

