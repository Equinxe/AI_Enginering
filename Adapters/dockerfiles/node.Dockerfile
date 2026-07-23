# IA Engineering — starter Dockerfile (Node.js)
#
# A minimal, multi-stage starter for a newly-bootstrapped Node project. Not a
# production-hardened image — adjust the build script, exposed port, and start
# command to match your application before relying on it.

# ---- build stage: install all deps and build ----
FROM node:lts-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
# Runs your build script if one is defined; a no-op otherwise.
RUN npm run build --if-present

# ---- runtime stage: slim image running production deps only ----
FROM node:lts-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
# Bring over the built app (including its node_modules) from the build stage...
COPY --from=build /app ./
# ...then drop devDependencies so the runtime image stays lean.
RUN npm prune --omit=dev
# TODO: set the port your app actually listens on.
EXPOSE 3000
# TODO: point this at your app's real entrypoint.
CMD ["node", "index.js"]
