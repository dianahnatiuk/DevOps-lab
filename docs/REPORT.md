# Звіт до лабораторної роботи №4

> Команди нижче потрібно виконати на вашій машині (Helm 3 + minikube) і вставити реальний вивід
> під кожним пунктом — я його не вигадував. Скріншоти/вивід — підтвердження виконання.

## 1. Середовище
```bash
helm version
minikube start
kubectl get all -n hnatiuk          # лаб. №3 працює
curl $(minikube service devops-app-svc -n hnatiuk --url)/health
kubectl delete -f k8s/              # видалити розгортання з лаб. №3 (конфлікт імен)
# якщо namespace створено вручну і лишився: kubectl delete ns hnatiuk
```

## 6. Два середовища
```bash
diff helm/devops-app/values-dev.yaml helm/devops-app/values-prod.yaml

helm template devops-app ./helm/devops-app -f helm/devops-app/values-dev.yaml  -n hnatiuk > /tmp/dev.yaml
helm template prod       ./helm/devops-app -f helm/devops-app/values-prod.yaml -n hnatiuk-prod > /tmp/prod.yaml
diff /tmp/dev.yaml /tmp/prod.yaml
```
Різниця dev → prod: репліки 1→4, ресурси (100m/128Mi → 200m/256Mi; ліміти 250m/256Mi → 500m/512Mi), тег образу 1.0.0→1.1.0, Ingress вимкнено→увімкнено (`devops-app.prod.local`), сервіс NodePort→ClusterIP, PVC 1Gi→5Gi, `APP_ENV`/`APP_GREETING`.

Пріоритет `values.yaml` < `-f` < `--set`:
```bash
helm template t ./helm/devops-app -f helm/devops-app/values-prod.yaml --set replicaCount=2 | grep "replicas:"
# replicas: 2  (--set перекриває 4 з prod-файлу, а той — 2 з values.yaml)
```

## 7. Перевірка і встановлення
```bash
helm lint ./helm/devops-app
helm lint ./helm/devops-app -f helm/devops-app/values-prod.yaml
helm template devops-app ./helm/devops-app > /tmp/rendered.yaml   # порівняти з k8s/00-07

helm install devops-app ./helm/devops-app -n hnatiuk --create-namespace -f helm/devops-app/values-dev.yaml
helm list -n hnatiuk
helm status devops-app -n hnatiuk
helm get values devops-app -n hnatiuk          # лише задані значення
helm get values devops-app -n hnatiuk --all    # усі значення
kubectl get secret -n hnatiuk                  # sh.helm.release.v1.devops-app.v1 (type helm.sh/release.v1)
```
Helm зберігає стан релізу в Secret типу `helm.sh/release.v1` з іменем `sh.helm.release.v1.<реліз>.v<ревізія>` у namespace релізу (у ньому закодований чарт, значення й маніфест).

Порівняння з лаб. №3: ті самі 7 типів об'єктів (ConfigMap, Secret, PVC, 2×Deployment, 2×Service); відмінності — імена будуються з релізу, мітки `app.kubernetes.io/*`, namespace задається прапорцем `-n`, пароль генерується.

## 8. Життєвий цикл
```bash
helm upgrade devops-app ./helm/devops-app -n hnatiuk -f helm/devops-app/values-dev.yaml --set image.tag=1.1.0     # rev 2
helm upgrade devops-app ./helm/devops-app -n hnatiuk -f helm/devops-app/values-prod.yaml                          # rev 3
helm history devops-app -n hnatiuk
helm rollback devops-app 2 -n hnatiuk                                                                             # rev 4
helm history devops-app -n hnatiuk
helm uninstall devops-app -n hnatiuk
kubectl get all,cm,secret,pvc,ingress -n hnatiuk                                                                  # порожньо
```
Що змінювалося: rev 2 — лише тег образу (rolling update, pre-upgrade хук); rev 3 — репліки, ресурси, тег, Ingress, сервіс, `APP_ENV`/`APP_GREETING`; rev 4 — відкат до стану rev 2 (це **нова** ревізія, історія не перезаписується; у `helm history` rev 2 і 3 лишаються як `superseded`).
Зауваження: переходячи на prod-файл, сервіс змінює тип NodePort→ClusterIP, а `storageSize` 1Gi→5Gi PVC не змінить (поле PVC не можна зменшувати/для bound PVC потрібен розширюваний клас) — для чистої демонстрації зручніше окремий реліз `prod` у `hnatiuk-prod`.

## 9 (варіант b). Хук і тест
- хук `pre-upgrade` — `templates/pre-upgrade-job.yaml`; спостерігати: `kubectl get jobs -n hnatiuk -w` під час `helm upgrade`;
- тест — `templates/tests/test-connection.yaml` (wget на `/health` сервісу):
```bash
helm test devops-app -n hnatiuk       # очікується Phase: Succeeded
```

## 10. Репозиторій
```bash
git add helm README.md REPORT.md
git commit -m "lab4: helm chart devops-app"
```