# Use Eclipse Temurin JDK 21 as base image
FROM eclipse-temurin:21-jdk-alpine AS builder

# Set working directory
WORKDIR /app

# Copy Maven files
COPY pom.xml .
COPY src ./src

# Install Maven
RUN apk add --no-cache maven

# Build the application
RUN mvn clean package -DskipTests

# Final stage
FROM eclipse-temurin:21-jre-alpine

# Set working directory
WORKDIR /app

# Create directories for DataDog
RUN mkdir -p /datadog/tracer
RUN mkdir -p /home/LogFiles

# Download DataDog Java tracer
ADD https://dtdg.co/latest-java-tracer /datadog/tracer/dd-java-agent.jar

# Copy the built jar from builder stage
COPY --from=builder /app/target/*.jar app.jar

# Set environment variables for DataDog
ENV DD_AGENT_HOST=localhost
ENV DD_TRACE_AGENT_PORT=8126
ENV DD_SERVICE=springboot-datadog-demo
ENV DD_ENV=poc
ENV DD_VERSION=1.0.0
ENV DD_LOGS_INJECTION=true
ENV DD_TRACE_SAMPLE_RATE=1
ENV JAVA_TOOL_OPTIONS=-javaagent:/datadog/tracer/dd-java-agent.jar

# Expose port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
