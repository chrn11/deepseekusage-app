# ====================
# Build Stage
# ====================
FROM swift:5.9-jammy AS builder

WORKDIR /build

# Copy package definition files first for layer caching
COPY Package.swift ./
COPY Sources/ ./Sources/
COPY Tests/ ./Tests/

# Build in release mode
RUN swift build -c release --static-swift-stdlib

# ====================
# Run Stage
# ====================
FROM ubuntu:jammy

RUN apt-get update && apt-get install -y \
    libsqlite3-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /build/.build/release/App /app/App

# Expose the default Vapor port
EXPOSE 8080

# The API key must be provided via environment variable
CMD ["./App", "serve", "--hostname", "0.0.0.0", "--port", "8080"]
