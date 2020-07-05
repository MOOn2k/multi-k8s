# Чтобы императивно присвивать поду деплоймента контейнер последней версии (нужной), мы должны эту версию как то
# обозначать. Пользуем $SHA - id текущего комита, ну и оставлем latest, чтобы самим видеть последний билд.
# PS: так кстати будет удобно делать дебаг. смотришь какая версия на сервере и просто делаешь git checkout *SHA*

docker build -t moon2k/complex-client:latest -t moon2k/complex-client:$SHA -f ./client/Dockerfile ./client
docker build -t moon2k/complex-server:latest -t moon2k/complex-server:$SHA -f ./server/Dockerfile ./server
docker build -t moon2k/complex-worker:latest -t moon2k/complex-worker:$SHA -f ./worker/Dockerfile ./worker

# Уже залогинены в вызывающем этот скрипт файле
# echo "$DOCKERHUB_PASSWORD" | docker login -u "$DOCKERHUB_LOGIN" --password-stdin

docker push moon2k/complex-client:latest
docker push moon2k/complex-client:$SHA
docker push moon2k/complex-server:latest
docker push moon2k/complex-server:$SHA
docker push moon2k/complex-worker:latest
docker push moon2k/complex-worker:$SHA

# У нас уже установлен kubectl, используем
kubectl apply -f k8s
kubectl set image deployments/client-deployment client=moon2k/complex-client:$SHA
kubectl set image deployments/server-deployment server=moon2k/complex-server:$SHA
kubectl set image deployments/worker-deployment worker=moon2k/complex-worker:$SHA

# Мы должны указать пароль для Postres, но тут это делать не секурно
# kubectl create secret generic pgpassword --from-literal "POSTGRES_PASSWORD=password"

# Делаем это через и нтерфейс хостера:
# Находсь в контексте проекта в правом верхнем углу жмем "Activate cloud shell" и вводим команду туда, предварительно
# проделав все те же операции по выбору проекта и тд как и в нашем .travis.yml:
# gcloud config set project multi-k8s-281522
# gcloud config set compute/zone europe-north1-c
# gcloud container clusters get-credentials multi-cluster
# kubectl create secret generic pgpassword --from-literal "POSTGRES_PASSWORD=password"

# Для внешнего достпа к приложению придется поставить ingress-nginx контроллер
# Описание установки для Google cloud тут: https://kubernetes.github.io/ingress-nginx/deploy/#gce-gke
# Однако для таких вещей правильнее использовать менеджер пакетов Helm
# И ставить его лучше из скрипта: https://helm.sh/docs/intro/install/#from-script
# curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
# chmod 700 get_helm.sh
# ./get_helm.sh
# Ставим ingress-nginx:
# helm repo add stable https://kubernetes-charts.storage.googleapis.com/
# helm install my-nginx stable/nginx-ingress --set rbac.create=true
