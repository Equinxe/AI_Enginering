# IA Engineering — starter Dockerfile (static web front end)
#
# For a site or single-page application that BUILDS TO STATIC FILES and is
# served by a web server: React, Vue, Svelte, Angular, Astro, or a static site
# generator. Not a production-hardened image — adjust the build command, the
# output directory, and the server configuration before relying on it.
#
# WHY THIS IS NOT THE NODE STARTER
#
# Both use Node to build. What they ship is not the same thing at all: the node
# starter ships a running Node process, this one ships a directory of files and
# a web server, with no Node in the final image. The runtime, the attack
# surface, the port, and the failure modes all differ.
#
# That difference is also why the `web` stack CANNOT BE INFERRED. Both have
# package.json, and no rule over file names tells a site from a server. It is
# selected only by `.ia-engineering/stack` — see Adapters/scripts/resolve-stack.sh.

# ---- build stage: produce the static bundle ----
FROM node:lts-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
# TODO: if your build script is not `build`, change it here.
RUN npm run build

# ---- runtime stage: a web server and the files, no Node ----
FROM nginx:stable-alpine AS runtime

# TODO: point this at your build output. The common defaults are `dist` (Vite,
# Astro, Svelte), `build` (Create React App), and `out` (Next.js static export).
# Getting it wrong produces an image that serves nginx's welcome page, which
# looks like a working deployment — check the container serves YOUR index.html
# before trusting it.
COPY --from=build /app/dist /usr/share/nginx/html

# A single-page application needs unknown paths routed back to index.html, or
# every deep link 404s once the user reloads the page. This is the smallest
# configuration that does that. DELETE IT if you are serving a multi-page site,
# where a 404 should stay a 404.
RUN printf '%s\n' \
      'server {' \
      '  listen 80;' \
      '  root /usr/share/nginx/html;' \
      '  location / { try_files $uri $uri/ /index.html; }' \
      '}' \
    > /etc/nginx/conf.d/default.conf

EXPOSE 80
# nginx's own image already sets an appropriate CMD; it is repeated here so
# that replacing the base image does not silently remove the entrypoint.
CMD ["nginx", "-g", "daemon off;"]
