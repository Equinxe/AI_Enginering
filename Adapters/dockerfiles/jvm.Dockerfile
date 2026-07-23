# IA Engineering — starter Dockerfile (JVM)
#
# A minimal, multi-stage starter for a newly-bootstrapped JVM project: build
# with a full JDK, run on a slim JRE. Supports Maven (pom.xml) or Gradle
# (build.gradle). Not production-hardened — adjust the build tool, artifact
# path, and port to match your application before relying on it.

# ---- build stage ----
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY . .
# Maven path (default): prefer the wrapper (./mvnw) when present, else system mvn.
RUN if [ -x ./mvnw ]; then ./mvnw -B package -DskipTests; else mvn -B package -DskipTests; fi
# Gradle path (use INSTEAD of the Maven line above if your project uses Gradle):
# RUN if [ -x ./gradlew ]; then ./gradlew build -x test; else gradle build -x test; fi

# ---- runtime stage ----
FROM eclipse-temurin:21-jre AS runtime
WORKDIR /app
# TODO: adjust the produced artifact path — Maven emits target/*.jar,
# Gradle emits build/libs/*.jar.
COPY --from=build /src/target/*.jar app.jar
# TODO: set the port your app actually listens on.
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
