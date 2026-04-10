# ============================================================
# Multi-Stage Dockerfile for Spring Boot Application
# WHY multi-stage: keep final image small (no JDK, only JRE)
# which also reduces our Trivy CVE surface area.
# ============================================================

# --- Stage 1: Build ---
FROM maven:3.9.6-eclipse-temurin-22 AS builder

WORKDIR /build

# Copy only pom.xml first to cache Maven dependencies layer
# WHY: If source code changes but pom.xml doesn't, this layer is cached
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Now copy source and build the JAR
COPY src ./src
RUN mvn clean package -DskipTests -B

# --- Stage 2: Runtime ---
FROM eclipse-temurin:21-jre-alpine

# Security: run as non-root user
# WHY: Never run containers as root in production
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy only the built JAR from the builder stage
COPY --from=builder /build/target/*.jar app.jar

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

USER appuser

# Expose application port
EXPOSE 8080

# Health check - K8s will also have liveness/readiness probes
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# JVM tuning for containers
ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -XX:+UseG1GC \
               -Djava.security.egd=file:/dev/./urandom"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
