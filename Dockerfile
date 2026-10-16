# Three stages:
#   base    - runtime dependencies only
#   test    - adds dev dependencies and RUNS THE TESTS during the build,
#             so a failing test fails `docker build --target test`
#   runtime - the small image that is scanned, pushed and deployed
FROM python:3.12-slim AS base
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM base AS test
COPY requirements-dev.txt .
RUN pip install --no-cache-dir -r requirements-dev.txt
COPY . .
# Reports are copied out by Jenkins (docker cp) for SonarQube and the build page.
RUN pytest --cov --cov-report=xml:coverage.xml --junitxml=junit.xml -q

FROM base AS runtime
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
RUN useradd --uid 10001 --create-home appuser
COPY app ./app
USER 10001
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "app.main:app"]
