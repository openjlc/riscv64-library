# 多架构 k3s组件构建脚本说明（

## 脚本概述
该脚本用于构建 K3s 生态组件的多架构 Docker 镜像（支持 amd64/arm64/arm/ppc64le/riscv64），主要包含以下组件：
- CoreDNS
- klipper-helm (Helm v2/v3)
- klipper-lb (负载均衡器)
- metrics-server (指标采集)
- traefik (Ingress 控制器)
- local-path-provisioner (本地存储供应器)
- pause (Kubernetes 基础镜像)
---

## 使用前准备
```bash
# 安装必要工具
sudo apt install -y git build-essential docker-buildx qemu-user-static

# 启用 buildx 多架构支持
docker run --rm --privileged multiarch/qemu-user-static --reset
docker buildx create --use
```
## 构建脚本
```
#!/bin/bash

set -xe

REPO=openjlc
TMPPATH=/build

##############
# Build Images
##############

mkdir -p $TMPPATH/k3s-images
pushd $TMPPATH/k3s-images

####
## CoreDNS
####

git clone https://github.com/coredns/coredns
cd coredns
VER=v1.8.0
git checkout ${VER}
GITCOMMIT=$(git describe --dirty --always)
for arch in amd64 arm arm64 riscv64 ppc64le; do
    CGO_ENABLED=0 GOOS=linux GOARCH=$arch go build -v \
        -ldflags="-s -w -X github.com/coredns/coredns/coremain.GitCommit=${GITCOMMIT}" \
        -o coredns-$arch .
done

cat > Dockerfile << 'EOF'
FROM alpine:3.13
RUN apk add --no-cache ca-certificates
ARG TARGETARCH
COPY coredns-$TARGETARCH /coredns
EXPOSE 53 53/udp
ENTRYPOINT ["/coredns"]
EOF

docker buildx build -t ${REPO}/coredns:${VER} \
    --platform linux/amd64,linux/arm64,linux/ppc64le,linux/arm,linux/riscv64 \
    --push .
cd ..

####
## klipper-helm
####

git clone https://github.com/rancher/klipper-helm
pushd klipper-helm
KLIPPERVERSION=v0.4.3
git checkout $KLIPPERVERSION

mkdir -p $GOPATH/k8s.io
git clone https://github.com/helm/helm $GOPATH/k8s.io/helm

# Build Helm v3
cd $GOPATH/k8s.io/helm
git checkout v3.7.1
make build-cross

# Build Helm v2
git checkout v2.16.10
make bootstrap
for ARCH in amd64 arm64 arm ppc64le riscv64; do
    GOOS=linux GOARCH=${ARCH} go build \
        -ldflags '-w -s -X k8s.io/helm/pkg/version.Version=v2.16.10' \
        -o _dist/linux-${ARCH}/helm ./cmd/helm
done

cat > Dockerfile << 'EOF'
FROM carlosedp/debian:sid
ARG TARGETARCH
RUN apt-get update && apt-get install -y ca-certificates
COPY _dist/linux-$TARGETARCH/helm /usr/bin/helm
ENTRYPOINT ["/usr/bin/helm"]
EOF

docker buildx build --platform linux/arm64,linux/arm,linux/amd64,linux/ppc64le,linux/riscv64 \
    -t $REPO/klipper-helm:$KLIPPERVERSION --push .
popd

####
## klipper-lb
####

git clone https://github.com/rancher/klipper-lb
pushd klipper-lb
KLIPPERLBVERSION=v0.1.2
git checkout ${KLIPPERLBVERSION}

cat > Dockerfile << 'EOF'
FROM debian:sid-slim
COPY entry /usr/bin/
CMD ["entry"]
EOF

docker buildx build --platform linux/arm64,linux/arm,linux/amd64,linux/ppc64le,linux/riscv64 \
    -t $REPO/klipper-lb:$KLIPPERLBVERSION --push .
popd

####
## metrics-server
####

git clone https://github.com/kubernetes-sigs/metrics-server
pushd metrics-server
MSVERSION=v0.5.0
git checkout $MSVERSION

GIT_COMMIT=$(git rev-parse HEAD)
for ARCH in amd64 arm64 arm ppc64le riscv64; do
    GOARCH=$ARCH GOOS=linux go build \
        -ldflags "-w -X sigs.k8s.io/metrics-server/pkg/version.gitCommit=$GIT_COMMIT" \
        -o _output/$ARCH/metrics-server ./cmd/metrics-server
done

cat > Dockerfile << 'EOF'
FROM gcr.io/distroless/static:latest
ARG TARGETARCH
COPY _output/$TARGETARCH/metrics-server /
ENTRYPOINT ["/metrics-server"]
EOF

docker buildx build --platform linux/arm64,linux/arm,linux/amd64,linux/ppc64le,linux/riscv64 \
    -t $REPO/metrics-server:$MSVERSION --push .
popd

####
## traefik
####

git clone https://github.com/traefik/traefik
pushd traefik
TRAEFIKVERSION=v2.5.6
git checkout ${TRAEFIKVERSION}

for arch in amd64 arm arm64 riscv64 ppc64le; do
    GOARCH=$arch make binary
done

cat > Dockerfile << 'EOF'
FROM scratch
ARG TARGETARCH
COPY dist/traefik_linux-$TARGETARCH /traefik
EXPOSE 80
ENTRYPOINT ["/traefik"]
EOF

docker buildx build -t ${REPO}/traefik:${TRAEFIKVERSION} \
    --platform linux/amd64,linux/arm64,linux/ppc64le,linux/arm,linux/riscv64 --push .
popd

####
## local-path-provisioner
####

git clone https://github.com/rancher/local-path-provisioner
pushd local-path-provisioner
LPPVERSION=v0.0.21
git checkout $LPPVERSION

for ARCH in amd64 arm64 arm ppc64le riscv64; do
    CGO_ENABLED=0 GOOS=linux GOARCH=$ARCH go build \
        -ldflags "-X main.VERSION=$LPPVERSION -extldflags -static -s -w" \
        -o bin/local-path-provisioner-$ARCH
done

cat > Dockerfile << 'EOF'
FROM scratch
ARG TARGETARCH
COPY bin/local-path-provisioner-$TARGETARCH /local-path-provisioner
ENTRYPOINT ["/local-path-provisioner"]
EOF

docker buildx build --platform linux/arm64,linux/arm,linux/amd64,linux/ppc64le,linux/riscv64 \
    -t $REPO/local-path-provisioner:$LPPVERSION --push .
popd

####
## pause
####

git clone https://github.com/kubernetes/kubernetes
pushd kubernetes
TAG=3.7
cd build/pause

for ARCH in amd64 arm arm64 ppc64le riscv64; do
    docker run --rm -v $PWD:/src -w /src \
        carlosedp/crossbuild-${ARCH} \
        make CC=${ARCH}-linux-gnu-gcc
done

cat > Dockerfile << 'EOF'
FROM scratch
ARG TARGETARCH
COPY bin/pause-$TARGETARCH /pause
ENTRYPOINT ["/pause"]
EOF

docker buildx build --platform linux/amd64,linux/arm64,linux/arm,linux/ppc64le,linux/riscv64 \
    -t $REPO/pause:$TAG --push .
popd

##############
# Finish
##############
popd
```
