# syntax=docker/dockerfile:1

FROM python:3.11-slim-bookworm

RUN apt-get update && apt-get install -y \
    build-essential \
    g++ \
    libmagickwand-dev \
    imagemagick \
    zip \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt requirements.txt

RUN pip install -r requirements.txt
RUN pip install gunicorn

COPY wsgi.py wsgi.py
COPY entrypoint.sh entrypoint.sh
COPY ./app /app
COPY ./migrations /migrations

EXPOSE 8000
RUN chmod +x entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
