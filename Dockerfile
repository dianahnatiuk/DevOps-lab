FROM python:3.11-slim

WORKDIR /app

# Оновлюємо системні пакети базового образу (закриває вразливості Debian з уже випущеними фіксами)
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
# setuptools/wheel у runtime не потрібні; їх видалення прибирає вразливі vendored-копії
# (jaraco.context, wheel) із базового образу
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt \
    && pip uninstall -y setuptools wheel

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]