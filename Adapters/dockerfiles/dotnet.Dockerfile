# IA Engineering — starter Dockerfile (.NET)
#
# A minimal, multi-stage starter for a newly-bootstrapped .NET project. Not a
# production-hardened image — adjust the target framework, the published
# assembly name, the exposed port, and the entrypoint before relying on it.
#
# The two image families are deliberate: the SDK image can build and is large,
# the ASP.NET runtime image can only run and is a fraction of the size. Copying
# the published output between them is what keeps the shipped image small
# without giving up a reproducible build.

# ---- build stage: restore, build, publish ----
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Project files first, so `restore` is cached independently of source changes.
# A solution-wide copy would invalidate that cache on every edit.
COPY *.sln* ./
COPY **/*.csproj ./
# TODO: this flattens project files into /src. If your solution has projects in
# subdirectories, restore their paths here — the .NET SDK expects the layout
# recorded in the .sln to exist.
RUN dotnet restore

COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

# ---- runtime stage: the ASP.NET runtime and the published output ----
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish ./

# The image runs as a non-root user, which the base image provides. Left
# explicit rather than inherited, so replacing the base image does not silently
# restore root.
USER $APP_UID

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# TODO: point this at your published assembly. It is named after your project,
# not after the solution.
CMD ["dotnet", "YourProject.dll"]
