# -------- Stage 1: Build --------
FROM maven:3.9.9-eclipse-temurin-17 AS builder

WORKDIR /app
COPY . .

# Build the jar (skip tests for faster build)
RUN mvn clean package -DskipTests

# -------- Stage 2: Runtime --------
FROM eclipse-temurin:17-jdk-alpine

WORKDIR /app

# Copy jar from builder stage
COPY --from=builder /app/target/*.jar app.jar

# Expose port (Spring Boot default)
EXPOSE 8080

# Run application
ENTRYPOINT ["java","-jar","app.jar"]