# DevOps Lab: FastAPI + PostgreSQL у Kubernetes

Навчальний REST API на FastAPI з базою даних PostgreSQL. Проєкт розгортається
в локальному кластері minikube за допомогою маніфестів з каталогу `k8s/`.

## Ендпоінти

| Метод | Шлях | Опис |
|---|---|---|
| GET | `/` | перевірка роботи API |
| GET | `/health` | проба для liveness і readiness |
| GET | `/info` | версія застосунку, ім'я пода, значення з ConfigMap |
| POST | `/items/?name=...` | створення запису в БД |
| GET | `/docs` | Swagger UI |

## Вимоги

Docker Desktop, minikube, kubectl.

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