FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
# setuptools/wheel у runtime не потрібні; їх видалення прибирає вразливі vendored-копії
# (jaraco.context, wheel) із базового образу
RUN pip install --no-cache-dir -r requirements.txt \
    && pip uninstall -y setuptools wheel

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]