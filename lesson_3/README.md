# OTUS_HI-2025-01  
## lesson_3_terraform  
### Краткое описание.
- Скачать репозиторий.  
- Создать аккаунт, проект, каталог, сервисный аккаунт, ssh ключ в YA CLOUD.  
- Установить Terraform и проинициализировать в скаченной репе.  
- Запустиь terraform apply -lock=false -auto-approve  
- Перейти в бразуер по ссылке http://ip_vm, где ip_vm ваш публичный IP адресс после создания ВМ через terraform.  
- Удалить ВМ. terraform destroy -lock=false -auto-approve.  
### Подрбное описание. Создание аккаунта в [Yandex Cloud](https://yandex.cloud/ru/docs/tutorials/infrastructure-management/terraform-quickstart)  
- Установили Yandex cli  
- Инициализировли клауд  
`yc init `
- Создали каталог в YA otushi-2025-01  
```
token: y0__xCo0ddkGMHdEyCat9qmEoclPClsy9I4VL7ToUM4I5Iy97MR
cloud-id: b1g9jfkl7r7n9sh782iv
folder-id: b1gr66gumfmr5ua86ol9
compute-default-zone: ru-central1-a
```

- Установили Terraform  
- Создали сервисный аккаунт  
```
done (1s)
id: ajeblp4m9hckn7r41pto
folder_id: b1gr66gumfmr5ua86ol9
created_at: "2025-02-17T17:48:32.936340596Z"
name: sedunovsv
```

- Назначили роль на ресурс  
`yc resource-manager cloud add-access-binding otushi-2025-01 --role admin --subject serviceAccount:ajeblp4m9hckn7r41pto`  

```
done (2s)
effective_deltas:
  - action: ADD
    access_binding:
      role_id: admin
      subject:
        id: ajeblp4m9hckn7r41pto
        type: serviceAccount

yc iam key create \
  --service-account-id ajeblp4m9hckn7r41pto \
  --folder-name otus \
  --output /home/sedunovsv/OTUS/key.json
id: aje9rvs7c2t5is6kfouu
service_account_id: ajeblp4m9hckn7r41pto
created_at: "2025-02-17T18:02:29.872263461Z"
key_algorithm: RSA_2048

yc config profile create sedunovsv
Profile 'sedunovsv' created and activated

yc config set service-account-key /home/sedunovsv/OTUS/key.json
yc config set cloud-id b1g9jfkl7r7n9sh782iv
yc config set folder-id b1gr66gumfmr5ua86ol9

yc resource-manager cloud list

+----------------------+----------------+----------------------+--------+
|          ID          |      NAME      |   ORGANIZATION ID    | LABELS |
+----------------------+----------------+----------------------+--------+
| b1g9jfkl7r7n9sh782iv | otushi-2025-01 | bpflocuh1rvic8l3g2p9 |        |
+----------------------+----------------+----------------------+--------+
```
- Экспортировали переменные. Добавлено в start.sh.  
```
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)
```
- Создали фаайл terraformrc для инициализации terraform.  
`nano ~/.terraformrc`
```
provider_installation {
  network_mirror {
    url = "https://terraform-mirror.yandexcloud.net/"
    include = ["registry.terraform.io/*/*"]
  }
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}
Где:
source — глобальный адрес источника провайдера.
required_version — минимальная версия Terraform, с которой совместим провайдер.
provider — название провайдера.
zone — зона доступности, в которой по умолчанию будут создаваться все облачные ресурсы.
```
- Инициализировали терраформ.  
`terraform init`
```
 Terraform has been successfully initialized!
```
- Создали сеть
```
yc vpc network list
yc vpc network create \
  --name otus-network \
  --description "OTUS Network"
id: enp1narlb6ut41r7mhmj
folder_id: b1gr66gumfmr5ua86ol9
created_at: "2025-02-17T18:37:16Z"
name: otus-network
description: OTUS Network
default_security_group_id: enp2f63gdevh8mbqv9s0

yc vpc subnet list
yc vpc subnet create \
  --name otus-subnet \
  --zone ru-central1-a \
  --network-id enp1narlb6ut41r7mhmj \
  --range 192.168.1.0/24
id: e9bhojlbqv19tdoi8hie
folder_id: b1gr66gumfmr5ua86ol9
created_at: "2025-02-17T18:38:01Z"
name: otus-subnet
network_id: enp1narlb6ut41r7mhmj
zone_id: ru-central1-a
v4_cidr_blocks:
```
- Создали SSH ключ для дальнейшего подключения к ВМ.  
```
Your public key has been saved in /home/sedunovsv/.ssh/id_ed25519.pub
```
- Добавили main.tf и сопутствующие файлы.  
- Провадилидоровали конфигурацию
`terraform validate`
```
Success! The configuration is valid.
```
- Отформатировали файлы.
`terraform fmt`
```
main.tf
```
- Запустили создание ВМ и получили переменные по IP.  
`terraform apply -lock=false -auto-approve`
```
external_ip_address_vm_1 = "89.169.154.190"
external_ip_address_vm_2 = "89.169.133.35"
internal_ip_address_vm_1 = "192.168.10.27"
internal_ip_address_vm_2 = "192.168.10.21"
```
- Присоединились к ВМ по SSH.  
`ssh -l sedunovsv 62.84.112.39`

- Далее убрал создание 4х ВМ, оставил только 1 ВМ и добавил в meta.txt установку nginx с кастомным выводом стартовой страницы.  
  Посмотреть можно через браузер http://ip_vm
- Удалить ВМ. terraform destroy -lock=false -auto-approve
