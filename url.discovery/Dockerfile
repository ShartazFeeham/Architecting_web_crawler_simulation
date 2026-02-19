# Stage 1: Build
FROM maven:3.9-eclipse-temurin-21-alpine AS build
WORKDIR /app
COPY pom.xml .
# Download dependencies for caching
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Runtime
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
# Leaner image: no need for shell or full JDK
COPY --from=build /app/target/*.jar app.jar

# Optimization: Run as non-root user
RUN addgroup -S spring && adduser -S spring -G spring
RUN mkdir -p /app/logs && chown spring:spring /app/logs
USER spring:spring

ENTRYPOINT ["java", "-jar", "app.jar"]
