# IA Engineering — starter Dockerfile (Generic fallback)
#
# No first-class stack (Node, Python, Go, JVM) was selected for this project.
# This file is a PLACEHOLDER: it will not build a usable image until you edit
# it. Every meaningful step below is commented out on purpose so the intent is
# explicit rather than guessed.
#
# Fill in the four TODOs, then remove the failing CMD guard at the bottom.

# A small, general-purpose base. Swap for whatever base image your runtime
# needs (e.g. ubuntu, alpine, a language-specific image).
FROM debian:stable-slim
WORKDIR /app

# TODO (1): install your runtime and/or toolchain, e.g.:
# RUN apt-get update \
#     && apt-get install -y --no-install-recommends <packages> \
#     && rm -rf /var/lib/apt/lists/*

# Copy your source into the image.
COPY . .

# TODO (2): build your application, e.g.:
# RUN make build

# TODO (3): declare the port your app listens on, e.g.:
# EXPOSE 8080

# TODO (4): replace the guard below with your real start command, e.g.:
# CMD ["./your-app"]
#
# Guard: fails fast so a forgotten placeholder never ships as a "working" image.
CMD ["sh", "-c", "echo 'generic.Dockerfile is a placeholder — replace CMD (and the TODOs above) with your app start command.' && exit 1"]
