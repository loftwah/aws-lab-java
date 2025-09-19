# syntax=docker/dockerfile:1.7

FROM public.ecr.aws/docker/library/gradle:8.8-jdk21 AS build
WORKDIR /workspace
COPY . .
RUN gradle --no-daemon clean bootJar

FROM public.ecr.aws/docker/library/eclipse-temurin:21-jre
WORKDIR /app
ENV JAVA_OPTS=""
RUN apt-get update \
  && apt-get install -y --no-install-recommends curl \
  && rm -rf /var/lib/apt/lists/*
COPY --from=build /workspace/build/libs/app.jar app.jar
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
