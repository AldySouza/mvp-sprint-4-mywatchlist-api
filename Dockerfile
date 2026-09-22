FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

# Banco SQLite fica num diretório próprio, montado como volume para persistir.
ENV DATABASE_URL=sqlite:////app/data/favoritos.db
RUN mkdir -p /app/data
VOLUME /app/data

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
