# IA Engineering — starter Dockerfile (Python)
#
# A minimal, single-stage starter for a newly-bootstrapped Python project. Not
# a production-hardened image — adjust the dependency install and start command
# to match your application before relying on it.

FROM python:3-slim AS runtime
WORKDIR /app

# Keep the image lean and logs unbuffered for container-friendly output.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install dependencies first so this layer is cached across code changes.
# TODO: if you use pyproject.toml instead of requirements.txt, replace the two
# lines below with:  COPY pyproject.toml ./  &&  RUN pip install --no-cache-dir .
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# TODO: point this at your app's real entrypoint.
CMD ["python", "main.py"]
