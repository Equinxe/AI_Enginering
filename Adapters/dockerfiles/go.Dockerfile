# IA Engineering — starter Dockerfile (Go)
#
# A minimal, multi-stage starter for a newly-bootstrapped Go project. Builds a
# static binary, then ships it in an empty `scratch` image for the smallest
# reasonable attack surface. Not production-hardened — adjust the build target
# and port to match your application before relying on it.

# ---- build stage ----
FROM golang:alpine AS build
WORKDIR /src
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
# CGO disabled -> a statically linked binary that runs on `scratch` (no libc).
# TODO: if your main package is not the module root, change `.` accordingly
# (e.g. ./cmd/server).
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/server .

# ---- runtime stage ----
FROM scratch AS runtime
# CA certificates for outbound TLS; remove if your service makes no HTTPS calls.
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /app/server /server
# TODO: set the port your app actually listens on.
EXPOSE 8080
ENTRYPOINT ["/server"]
