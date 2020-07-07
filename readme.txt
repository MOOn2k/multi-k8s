Сервис Complex-app - рассчет чисел Фибоначчи.
Описание проекта и его деплоя без кубов см в 'complex-app'. Тут речь только о кубах.

docker-compose
Dockerrun.aws.json
Удаляются. Мы полагаемся только на кубы на локалке и в продакшене.

.travis
Удаляется. Будет персоздан.

nginx
Удаляем. Пользовали для раутинга, но теперь этим займется Ingres service.

В папке k8s создаем файлы конфигурации для всех необходимых нам k8s объектов.
- Deployments для каждого из компонентов complex-app
- Services/ClusterIP для каждого Deployment чтобы открыть порт его контейнера в рамках кластера
- Services/Ingress для доступа к серверу и клиенту complex-app извне
PS: Services/NodePort нам более не подходит, тк каждому из Deployment дает доступ извне, а на проде так нельзя.

Для зпуска:
Удаляем ранее запущенное
> kubectl delete service/deployment ...
PS: или еще можно попробовать > kubectl delete -f k8s
> kubectl apply -f k8s


Конфиги можно объединять. Например сделать один файл с ClusterIP и Deployment для server, допустим server-config.yaml
Работает это путем отделения описаний через тройное тире:
```
Deployment config
---
ClusterIP config
```
Ну лучше так не делать для ясности понимания что и где менять..

Чтобы смотреть логи мы получаем находим нужный нам под и подставляем его id в следующую команду:
> kubectl logs worker-deployment-d597fbc97-f9vvb

ВНЕШНЕЕ ХРАНИЛИЩЕ
---
PersistentVolumeClaim
Это объект предложения поду по выделению места для хранения данных снаружи.
Основных опций две: сколько места выделить и способ (указывает на правило, будет дефолтовое если не выбрано).
Доступные варианты по способам получаются командой:
> kubectl get storageclass
На локалке для миникуба он будет один. Называется о standart и действует по правилу (Provisioner) minikube-hostpath,
которое говорит о том, что место будет отщипываться от хоста миникуба.
У облачного провайдера (например AWS) место будет выделяться через его местные сервисы (например AWS Block store),
которые так же будут представлены вариантами на выбор, ну и, как и в случае локалки, будет выбран какой то дефолтовый
если не указано другого.
Следующая команда отобразит все объекты запросов места:
> kubectl get pvc
Следующая команда отобразит все объекты полученных из них хранилищ:
> kubectl get pv

ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
---
Перечисляются в ключе env описываемого для пода контейнера.
Когда мы хотим обозначить внутри глобальной переменной HOST другого пода, то просто пишем имя его ClusterIP сервиса.
Для записи секретных значений используется объект Secret, но создается он императивно, не через конфиг:
> kubectl create secret generic pgpassword --from-literal "POSTGRES_PASSWORD=postgres_password"
существует три типа:
generic - закодированная пара ключ:значение
docker-registry - аутентификаци с кастомным реджистри
tls - используется для https
создавать можно из:
--from-literal - из строчки "key=value"
--from-file - файла
> kubectl create -f - файла объекта Secret
Так можно посмотреть все созданные  секреты:
> kubectl get secrets

ОТКРЫТИЕ ПОРТА НАРУЖУ
---
Порт наружу можно открыть используя 2 типа сервис объектов:
LoadBalancer - легаси. Вешается вместо ClusterIP на конкретный под и позволяет ему смотреть наружу.
Ingress - обеспечивает раутрнг трафика наружу для нескольких ClusterIP.

Ingress
Существует несколько вариантов:
ingress-nginx - проект K8s community.
kubernetes-ingress - проект nginx.
По сути похоже но работают по разному. Чаще пользуют ingress-nginx (и в курсе он же).

Kubernetes-ingress
Создается конфиг с раутингом, он применяется в kubectl и с ним начинает работать IngressController.
Обычно IngressController управляет неким подом с ПО типа nginx, но в данном случае это два в одном.
Развертывается по разному для разных провайдеров и локалки. Так например на Google Cloud пкред ним будет стоять
LoadBalancer гугла.

Почему нельзя просто взять под с nginx и повесить на LoadBalancer вместо Ingress, ведь результат будет тот же ?
Потому что nginx будет стучаться напрямую в порт одной реплики пода, без распределния нагрузки. Он не занет о k8s и не
умеет работать с ними.

Запускается IngressController так https://kubernetes.github.io/ingress-nginx/deploy/#minikube (strandart usage)
> minikube addons enable ingres
Результатом будет ingress-nginx, а не kubernetes-ingress

HEML (3)
---
Менеджер пакетов (чартов) в рамках кластера K8s. Позволяет поставить тот же Kubernetes-ingress
Сайт: https://helm.sh
Установка:
> curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
> chmod 700 get_helm.sh
> ./get_helm.sh
Установка пакета :
> helm repo add stable https://kubernetes-charts.storage.googleapis.com/
> helm install my-nginx stable/nginx-ingress --set rbac.create=true
PS: Все через шелл хостера

RBAC
---
Role Based Access Control. Система для предоставления прав на изменение объектов в кластере K8s. Включена на
Google cloud по дефолту. На minikube отключена.
Аккаунты могут быть двух типов:
Service Account - аккаунт пода в кластере, который будет им управлять.
User Account - аккаунт пользователя в кластере, который будет им управлять.
Роли бывают двух типов:
ClusterRoleBinding - роль в рамках кластера.
RoleBinding - роль в рамках объекта неймспейса кластера.

Ниже примере по работе с RBAC на примере Helm 1/2, в которых приложение делилось на две составляющие: сервер живущий в
поде кластера Till и вносящий в него изменений, а так же сам клиент Helm, который этому серверу должен был задачи по
изменению кластера ставить.
Так вот. Till должен иметь Service Account, чтобы вносить изменения. Настраиваем:

1. Создаем Service Account с именем tiller (не понял почему именно kube-system выбран namespace'ом)
> kubectl create serviceaccount --namespace kube-system tiller
2. Создаем правило ClusterRoleBinding с именем tiller-cluster-rule и назначаем этому правилу роль cluster-admin,
привязываем ее к Service Account
> kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
Теперь мы можем сделать init Helm'а:
> helm init --service-account=tiller --upgrage
PS: Все через шелл хостера или куда оно там ставится

ДОМЕН И HTTPS (tls)
---
По аналогии с контроллером 'ingress-nginx' в кластере так же могут быть развернуты и иные вспомогательные инструменты,
такие как, например, 'cert manager' - контроллер, обеспечивающий автоматизацию получения/обновления и управление tls
сертификатами из поддерживаемого перечня поставщиков.
Сайт: https://cert-manager.io/
Установка через Helm:
вместо версии из туториала..
> kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.11/deploy/manifests/00-crds.yaml
.. я буду ставить 0.15.1 согласно документации (CRDs для моего текущего кластера k8s < 1.15, а потому строчка такая)
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.1/cert-manager-legacy.crds.yaml
> kubectl create namespace cert-manager
> helm repo add jetstack https://charts.jetstack.io
> helm repo update
> helm install \
    cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --version v0.15.1
Согласно документации создается два объекта: ClusterIssuer и Certificate и применяем их в кластере.
