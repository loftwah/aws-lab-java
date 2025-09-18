# syntax=docker/dockerfile:1.7

FROM gradle:8.7-jdk21 AS build
WORKDIR /workspace
COPY . .
RUN gradle --no-daemon clean bootJar

FROM eclipse-temurin:21-jre
WORKDIR /app
ENV JAVA_OPTS=""
COPY --from=build /workspace/build/libs/app.jar app.jar
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
