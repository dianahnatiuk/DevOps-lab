# DevOps Lab: FastAPI + PostgreSQL у Kubernetes

Навчальний REST API на FastAPI з базою даних PostgreSQL. Проєкт розгортається
в локальному кластері minikube за допомогою маніфестів з каталогу `k8s/`
або Helm-чарта з каталогу `helm/devops-app/` (лабораторна робота №4, див. нижче).

## Ендпоінти

| Метод | Шлях | Опис |
|---|---|---|
| GET | `/` | перевірка роботи API |
| GET | `/health` | проба для liveness і readiness |
| GET | `/info` | версія застосунку, ім'я пода, значення з ConfigMap |
| POST | `/items/?name=...` | створення запису в БД |
| GET | `/docs` | Swagger UI |

## Вимоги

Docker Desktop, minikube, kubectl, Helm 3.

## Локальний запуск (docker compose)

    docker compose up --build

Застосунок буде доступний на http://localhost:8000.

## Розгортання в Kubernetes

1. Запустити кластер і доповнення:

        minikube start --driver=docker
        minikube addons enable metrics-server
        minikube addons enable ingress

2. Застосувати всі маніфести однією командою:

        kubectl apply -f k8s/

3. Перевірити створені об'єкти:

        kubectl get pods,deploy,rs,svc,pvc -n hnatiuk

4. Відкрити застосунок:

        kubectl port-forward svc/devops-app-svc 8080:80 -n hnatiuk

   Після цього: http://localhost:8080/docs, http://localhost:8080/info

5. Видалити все:

        kubectl delete -f k8s/

## Образи

Образи публікуються в GitHub Container Registry з конкретними тегами версій
(тег `latest` не використовується):

- `ghcr.io/dianahnatiuk/devops-lab:1.0.0`
- `ghcr.io/dianahnatiuk/devops-lab:1.1.0`

## Маніфести (каталог `k8s/`)

| Файл | Об'єкт | Призначення |
|---|---|---|
| 00-namespace.yaml | Namespace | окремий простір імен `hnatiuk` |
| 01-configmap.yaml | ConfigMap | нечутлива конфігурація |
| 02-secret.yaml | Secret | чутливі параметри |
| 03-postgres-pvc.yaml | PersistentVolumeClaim | сховище даних PostgreSQL |
| 04-postgres-deployment.yaml | Deployment | база даних (1 репліка) |
| 05-postgres-service.yaml | Service (ClusterIP) | доступ до БД всередині кластера |
| 06-app-deployment.yaml | Deployment | застосунок (3 репліки, проби, requests/limits) |
| 07-app-service.yaml | Service (NodePort) | доступ до застосунку |
| 08-ingress.yaml | Ingress | маршрутизація за хостом `devops-app.local` |

## Параметри ConfigMap (`devops-app-config`)

| Ключ | Значення | Опис |
|---|---|---|
| APP_ENV | production | режим роботи застосунку |
| APP_GREETING | Hello from Kubernetes | привітальний текст у `/info` |
| POSTGRES_DB | appdb | назва бази даних |
| POSTGRES_USER | appuser | користувач бази даних |

## Параметри Secret (`devops-app-secret`)

| Ключ | Опис |
|---|---|
| POSTGRES_PASSWORD | пароль користувача БД |
| DATABASE_URL | рядок підключення застосунку до PostgreSQL |

Значення в Secret вигадані та призначені лише для навчального стенду.
Реальні паролі в репозиторій не потрапляють.

## Керування життєвим циклом

    # масштабування
    kubectl scale deployment devops-app --replicas=5 -n hnatiuk

    # оновлення образу (rolling update)
    kubectl set image deployment/devops-app devops-app=ghcr.io/dianahnatiuk/devops-lab:1.1.0 -n hnatiuk
    kubectl rollout status deployment/devops-app -n hnatiuk

    # історія та відкат
    kubectl rollout history deployment/devops-app -n hnatiuk
    kubectl rollout undo deployment/devops-app -n hnatiuk

## CI

Pipeline GitHub Actions (`.github/workflows/ci.yml`) запускає лінтер ruff
та тести pytest.

---

# Helm-чарт (лабораторна робота №4)

Чарт `helm/devops-app/` описує той самий застосунок, що й маніфести з `k8s/`:
ConfigMap, Secret, PVC, Deployment і Service для PostgreSQL та застосунку, а також
необов'язковий Ingress. Namespace створюється командою `helm install --create-namespace`,
тому в чарті немає окремого шаблону Namespace.

## Структура чарта

    helm/devops-app/
      Chart.yaml
      values.yaml            # значення за замовчуванням (dev)
      values-dev.yaml
      values-prod.yaml
      templates/
        _helpers.tpl         # імена та мітки (include)
        NOTES.txt            # підказка після встановлення
        configmap.yaml
        secret.yaml
        postgres-pvc.yaml
        postgres-deployment.yaml
        postgres-service.yaml
        app-deployment.yaml
        app-service.yaml
        ingress.yaml
        pre-upgrade-job.yaml # хук pre-upgrade
        tests/test-connection.yaml  # helm test

Імена об'єктів будуються з імені релізу, тому чарт можна встановити кілька разів
в один кластер. Для релізу `devops-app` це `devops-app`, `devops-app-config`,
`devops-app-secret`, `devops-app-svc`, `devops-app-postgres`, `devops-app-postgres-data`.

## Різниця між `version` та `appVersion`

- **`version`** (`Chart.yaml`, зараз `0.1.0`) — версія самого Helm-чарта (пакета з шаблонами).
  Збільшується при зміні шаблонів, нових параметрах у `values.yaml` чи виправленні маніфестів.
- **`appVersion`** (`Chart.yaml`, зараз `1.0.0`) — версія застосунку (тег Docker-образу `devops-lab`),
  який розгортає чарт.

Вони незалежні: виправлення шаблону Ingress піднімає лише `version`, а вихід образу
`1.1.0` змінює `appVersion` і тег образу у `values-prod.yaml`.

## Параметри `values.yaml`

| Параметр | За замовчуванням | Опис |
|---|---|---|
| `replicaCount` | `2` | Кількість реплік застосунку |
| `image.repository` | `ghcr.io/dianahnatiuk/devops-lab` | Репозиторій образу |
| `image.tag` | `"1.0.0"` | Тег образу |
| `image.pullPolicy` | `IfNotPresent` | Політика завантаження образу |
| `containerPort` | `8000` | Порт контейнера |
| `service.type` | `NodePort` | Тип сервісу (`NodePort`, `ClusterIP`) |
| `service.port` | `80` | Порт сервісу |
| `service.targetPort` | `8000` | Порт застосунку |
| `service.nodePort` | `30080` | NodePort (порожнє — призначить Kubernetes) |
| `config.appEnv` | `"development"` | Змінна `APP_ENV` у ConfigMap |
| `config.appGreeting` | `"Hello from Helm-managed Kubernetes (Dev)!"` | Змінна `APP_GREETING` |
| `resources.requests` | `100m` / `128Mi` | Запити CPU/пам'яті застосунку |
| `resources.limits` | `250m` / `256Mi` | Ліміти CPU/пам'яті застосунку |
| `healthPath` | `/health` | Шлях для проб і `helm test` |
| `postgres.enabled` | `true` | Розгортати PostgreSQL |
| `postgres.image.repository` / `tag` | `postgres` / `"16"` | Образ БД |
| `postgres.dbName` / `dbUser` | `appdb` / `appuser` | База даних і користувач |
| `postgres.dbPassword` | `""` | Пароль БД; порожній — генерується випадковий і зберігається між оновленнями |
| `postgres.persistence.enabled` | `true` | Створювати PVC для даних БД |
| `postgres.storageSize` | `1Gi` | Обсяг PVC |
| `postgres.storageClass` | `""` | Клас сховища (порожній — типовий) |
| `postgres.resources` | `100m`/`128Mi` — `500m`/`512Mi` | Ресурси БД |
| `ingress.enabled` | `false` | Створювати Ingress |
| `ingress.className` / `host` / `path` | `nginx` / `devops-app.local` / `/` | Параметри Ingress |
| `hooks.preUpgrade.enabled` | `true` | Хук `pre-upgrade` |

Реальні паролі у файлах значень не зберігаються: пароль БД чарт генерує сам
або він передається через `--set postgres.dbPassword="$DB_PASSWORD"`.

## Середовища

| Параметр | dev (`values-dev.yaml`) | prod (`values-prod.yaml`) |
|---|---|---|
| `replicaCount` | 1 | 4 |
| `image.tag` | 1.0.0 | 1.1.0 |
| `resources` | 100m/128Mi — 250m/256Mi | 200m/256Mi — 500m/512Mi |
| `service.type` | NodePort | ClusterIP |
| `postgres.storageSize` | 1Gi | 5Gi |
| `ingress.enabled` | false | true (`devops-app.prod.local`) |

Різницю можна побачити без встановлення в кластер:

    diff helm/devops-app/values-dev.yaml helm/devops-app/values-prod.yaml
    helm template devops-app ./helm/devops-app -f helm/devops-app/values-dev.yaml > /tmp/dev.yaml
    helm template prod ./helm/devops-app -f helm/devops-app/values-prod.yaml > /tmp/prod.yaml
    diff /tmp/dev.yaml /tmp/prod.yaml

## Встановлення

### 1. Очищення розгортання з лабораторної №3

    kubectl delete -f k8s/

### 2. Перевірка чарта

    helm lint ./helm/devops-app
    helm template devops-app ./helm/devops-app

### 3. Середовище dev

    helm install devops-app ./helm/devops-app -n hnatiuk --create-namespace \
      -f helm/devops-app/values-dev.yaml

### 4. Середовище prod (окремий namespace)

    helm install prod ./helm/devops-app -n hnatiuk-prod --create-namespace \
      -f helm/devops-app/values-prod.yaml

Інструкцію з відкриття застосунку виводить `NOTES.txt`. Для dev:

    minikube service devops-app-svc -n hnatiuk --url
    # або
    kubectl port-forward svc/devops-app-svc 8080:80 -n hnatiuk

Для prod з Ingress додайте в `/etc/hosts` рядок `<minikube ip> devops-app.prod.local`.

## Пріоритет значень

Від нижчого до вищого:

1. `values.yaml` у чарті;
2. файли `-f` (кожен наступний перекриває попередній);
3. прапорці `--set`, `--set-string`, `--set-file` (найвищий пріоритет).

Приклад: `-f values-prod.yaml --set replicaCount=2` дасть 2 репліки, хоча в prod-файлі їх 4.

## Керування релізом

    helm list -n hnatiuk
    helm status devops-app -n hnatiuk
    helm get values devops-app -n hnatiuk          # значення, задані при встановленні
    helm get values devops-app -n hnatiuk --all    # усі значення

    # оновлення тега образу
    helm upgrade devops-app ./helm/devops-app -n hnatiuk \
      -f helm/devops-app/values-dev.yaml --set image.tag=1.1.0

    # оновлення зі значеннями іншого середовища
    helm upgrade devops-app ./helm/devops-app -n hnatiuk -f helm/devops-app/values-prod.yaml

    # історія, відкат, видалення
    helm history devops-app -n hnatiuk
    helm rollback devops-app 1 -n hnatiuk
    helm uninstall devops-app -n hnatiuk

Стан релізу Helm зберігає в Secret типу `helm.sh/release.v1` з іменем
`sh.helm.release.v1.<реліз>.v<ревізія>` у namespace релізу
(`kubectl get secret -n hnatiuk`).

## Хук і тест релізу

- `pre-upgrade-job.yaml` — Job-хук, який запускається перед кожним `helm upgrade`
  (вимикається параметром `hooks.preUpgrade.enabled=false`).
- `tests/test-connection.yaml` — Pod, що перевіряє `/health` сервісу:

      helm test devops-app -n hnatiuk