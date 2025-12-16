# Быстрый старт: Terraform + Proxmox

## Шаг 1: Установка Proxmox

См. подробные инструкции в [INSTALL_PROXMOX.md](INSTALL_PROXMOX.md)

**Кратко:**
- Установите Proxmox VE на сервер или в виртуальной машине
- Создайте API токен в веб-интерфейсе Proxmox
- Сохраните Token ID и Token Secret

## Шаг 2: Настройка Terraform

1. **Перейдите в каталог terraform:**
   ```bash
   cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_19/terraform
   ```

2. **Скопируйте пример файла переменных:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Отредактируйте terraform.tfvars:**
   ```bash
   nano terraform.tfvars
   # или
   vim terraform.tfvars
   ```

4. **Заполните обязательные параметры:**
   ```hcl
   # Proxmox connection
   proxmox_api_url          = "https://YOUR_PROXMOX_IP:8006/api2/json"
   proxmox_api_token_id     = "terraform@pve!terraform-token"
   proxmox_api_token_secret = "your-token-secret-here"
   proxmox_node_name        = "pve"  # Имя вашей ноды Proxmox
   
   # VM settings
   vm_name        = "terraform-vm"
   vm_cpu_cores   = 2
   vm_memory      = 2048  # MB
   vm_disk_size   = "20G"
   
   # Network
   vm_network_bridge = "vmbr0"
   
   # SSH key
   ssh_public_key_file = "~/.ssh/id_ed25519.pub"
   ```

## Шаг 3: Подготовка шаблона/ISO

Для создания ВМ вам нужен либо:
- **ISO образ** операционной системы (например, Ubuntu Server)
- **Шаблон** (template) для клонирования

### Загрузка ISO в Proxmox:

1. Войдите в веб-интерфейс Proxmox
2. Перейдите в **Datacenter** → **local** → **ISO Images**
3. Нажмите **Upload** и загрузите ISO файл
4. Укажите путь в `vm_disk_template`, например:
   ```hcl
   vm_disk_template = "local:iso/ubuntu-22.04-server-amd64.iso"
   ```

### Или используйте шаблон:

Если у вас есть шаблон (например, из Cloud Images):
```hcl
vm_disk_template = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
```

## Шаг 4: Инициализация Terraform

```bash
cd terraform
terraform init
```

Это загрузит необходимый провайдер Proxmox.

## Шаг 5: Просмотр плана

```bash
terraform plan
```

Проверьте, что план выглядит правильно. Вы должны увидеть создание одной виртуальной машины.

## Шаг 6: Развёртывание

### Вариант 1: Использование скрипта
```bash
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_19
./deploy-vm.sh
```

### Вариант 2: Ручное выполнение
```bash
cd terraform
terraform apply
```

Введите `yes` для подтверждения.

## Шаг 7: Проверка

1. **Проверьте вывод Terraform:**
   ```bash
   terraform output
   ```

2. **Проверьте в веб-интерфейсе Proxmox:**
   - Войдите в Proxmox
   - Перейдите в раздел виртуальных машин
   - Найдите ВМ с именем, указанным в `vm_name`

3. **Проверьте статус ВМ:**
   ```bash
   terraform output vm_status
   terraform output vm_ipv4_addresses
   ```

## Параметры ВМ

В конфигурации указаны следующие параметры:

- **Имя**: `vm_name` (по умолчанию: "terraform-vm")
- **CPU**: `vm_cpu_cores` ядер (по умолчанию: 2)
- **RAM**: `vm_memory` MB (по умолчанию: 2048 MB = 2 GB)
- **Диск**: `vm_disk_size` (по умолчанию: 20G)
- **Сеть**: мост `vm_network_bridge` (по умолчанию: vmbr0), модель `vm_network_model` (по умолчанию: virtio)

Все параметры можно изменить в файле `terraform.tfvars`.

## Удаление ВМ

Если нужно удалить созданную ВМ:

```bash
cd terraform
terraform destroy
```

## Устранение проблем

### Ошибка: "Unable to connect to Proxmox API"
- Проверьте URL Proxmox сервера
- Убедитесь, что порт 8006 открыт
- Проверьте правильность API токена

### Ошибка: "Template not found"
- Убедитесь, что шаблон/ISO загружен в Proxmox
- Проверьте правильность пути в `vm_disk_template`
- Проверьте имя datastore в `vm_disk_datastore`

### Ошибка: "Insufficient permissions"
- Проверьте права доступа API токена
- Убедитесь, что токен имеет права на создание ВМ

## Дополнительная информация

- Подробная документация: [README.md](README.md)
- Инструкции по установке Proxmox: [INSTALL_PROXMOX.md](INSTALL_PROXMOX.md)

