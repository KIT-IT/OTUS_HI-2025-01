# Top file for Pillar
# Определяет какие pillar данные применять к каким серверам

base:
  '*':
    - common
  
  'salt-master':
    - salt_master
  
  'nginx-*':
    - nginx
  
  'backend-*':
    - backend

