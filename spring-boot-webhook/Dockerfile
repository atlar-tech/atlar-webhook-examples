FROM eclipse-temurin:20-jdk as build
WORKDIR /src
COPY ./gradle ./gradle
COPY ./gradlew .
RUN ./gradlew --no-daemon
COPY . .
RUN ./gradlew bootJar --no-daemon

FROM eclipse-temurin:20-jre
COPY --from=build /src/build/libs/spring-boot-webhook-0.0.1-SNAPSHOT.jar /app.jar
CMD ["java", "-jar", "/app.jar"]
