# OTUS_HI-2025-01  
## lesson_6_nginx  
### Краткое описание.
- В качестве фронтенда был использован [vscoder/webdebugger](https://github.com/vscoder/webdebugger/blob/master/README.md)
- Скачать репозиторий.  
- Создать аккаунт, проект, каталог, сервисный аккаунт, ssh ключ в YA CLOUD.  
- Установить Terraform и проинициализировать в скаченной репе.  
- Запустить terraform apply -lock=false -auto-approve  
- После запуска terraform выдаст сообщение "IP для балансировки: ip:8000"
- Перейти в бразуер по ссылке http://ip:8000 и понажимать F5. Цвет фона должен будет менять с белого на зеленый, тем самым происходит балансировка.
- Удалить все ВМ. terraform destroy -lock=false -auto-approve.
- Задание с *.  
  Для установки окружения был использован Terraform, Ansible playbook в каталоге ansible, где устанавливаются зависимости, сам wordpress, mysql и nginx.

