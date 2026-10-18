FROM python:3.14.8-slim

ENV PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

RUN groupadd --gid 10001 app \
	&& useradd --uid 10001 --gid app --create-home --shell /usr/sbin/nologin app

COPY --chown=10001:10001 . /app/
RUN pip install --no-cache-dir pipenv && pipenv install --system

USER 10001:10001
