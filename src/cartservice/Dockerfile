# syntax=docker/dockerfile:1.7

FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:9.0.101-noble@sha256:1f13e67d295e02abdfd187c341f887442bad611eda536766172ced401fc8b9fa AS builder
ARG TARGETOS
ARG TARGETARCH
WORKDIR /app
# TEST
# Map Docker arch -> .NET arch + RID
# amd64 -> x64 / linux-x64
# arm64 -> arm64 / linux-arm64
# 386   -> x86 / linux-x86 (rare)
RUN case "$TARGETARCH" in \
      amd64) echo x64  > /tmp/dotnet_arch && echo linux-x64  > /tmp/dotnet_rid ;; \
      arm64) echo arm64> /tmp/dotnet_arch && echo linux-arm64> /tmp/dotnet_rid ;; \
      386)   echo x86  > /tmp/dotnet_arch && echo linux-x86  > /tmp/dotnet_rid ;; \
      *)     echo "Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac
ENV DOTNET_ARCH=$(cat /tmp/dotnet_arch)
ENV DOTNET_RID=$(cat /tmp/dotnet_rid)

# Copy project file first to leverage restore layer cache
COPY cartservice.csproj .

# Use BuildKit cache for NuGet, restore for the target RID
RUN --mount=type=cache,target=/root/.nuget/packages \
    dotnet restore cartservice.csproj \
      -r $DOTNET_RID

# Copy the rest of the sources
COPY . .

# Publish self-contained, single file for the mapped arch+RID
RUN --mount=type=cache,target=/root/.nuget/packages \
    dotnet publish cartservice.csproj \
      -c Release \
      -a $DOTNET_ARCH \
      -r $DOTNET_RID \
      --self-contained true \
      -p:PublishSingleFile=true \
      -p:PublishTrimmed=true \
      -p:TrimMode=full \
      -o /cartservice
