# syntax=docker/dockerfile:1.7

FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:9.0.101-noble@sha256:1f13e67d295e02abdfd187c341f887442bad611eda536766172ced401fc8b9fa AS builder
ARG TARGETOS
ARG TARGETARCH
WORKDIR /app

# Map Docker arch -> .NET arch + RID
RUN case "$TARGETARCH" in \
      amd64) echo x64  > /tmp/dotnet_arch && echo linux-x64  > /tmp/dotnet_rid ;; \
      arm64) echo arm64> /tmp/dotnet_arch && echo linux-arm64> /tmp/dotnet_rid ;; \
      386)   echo x86  > /tmp/dotnet_arch && echo linux-x86  > /tmp/dotnet_rid ;; \
      *)     echo "Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac

# Copy project file first to leverage restore layer cache
COPY cartservice.csproj .

# Restore using computed RID (inline so it's always present)
RUN --mount=type=cache,target=/root/.nuget/packages \
    dotnet restore cartservice.csproj -r "$(cat /tmp/dotnet_rid)"

# Copy the rest of the sources
COPY . .

# Publish self-contained, single-file using the computed RID
RUN --mount=type=cache,target=/root/.nuget/packages \
    dotnet publish cartservice.csproj \
      -c Release \
      -r "$(cat /tmp/dotnet_rid)" \
      --self-contained true \
      --no-restore \
      -p:PublishSingleFile=true \
      -p:PublishTrimmed=true \
      -p:TrimMode=full \
      -o /cartservice
