# RISC-V 架构 Podman 安装与配置指南（修正版）

## 系统要求
- ​**架构**: RISC-V 64 位 (riscv64)
- ​**支持系统**: Fedora 38+/Debian 12+
- ​**内核**: Linux 5.4+（需启用 OverlayFS/CGroups）

---

## 预编译包安装（Debian）

```bash
# 下载正确的 deb 包
wget https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/podman-1.8.1_riscv64.deb

# 安装
sudo apt install ./podman-1.8.1_riscv64.deb
```
## 源码编译（Fedora/Debian 通用）
1. 安装依赖
```bash
# Fedora
sudo dnf install -y git make golang libseccomp-devel glib2-devel

# Debian
sudo apt update && sudo apt install -y git make golang libseccomp-dev libglib2.0-dev
```
2. 配置 Go 环境
```bash
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
```
3. 编译 libseccomp
```bash
git clone https://github.com/seccomp/libseccomp
cd libseccomp
./autogen.sh && ./configure --prefix=/usr
make && sudo make install
```
4. 编译 crun
```bash
git clone https://github.com/giuseppe/crun
cd crun
./autogen.sh && ./configure --prefix=/usr
make
sudo make install
```
5. 编译 CNI 插件
```bash
git clone https://github.com/containernetworking/plugins $GOPATH/src/github.com/containernetworking/plugins
cd $GOPATH/src/github.com/containernetworking/plugins
./build_linux.sh
sudo mkdir -p /usr/libexec/cni
sudo cp bin/* /usr/libexec/cni
```
6. 编译 Podman
```bash
git clone https://github.com/containers/podman $GOPATH/src/github.com/containers/podman
cd $GOPATH/src/github.com/containers/podman
make BUILDTAGS="systemd exclude_graphdriver_devicemapper"
sudo make install
```
## 配置文件设置
1. 创建必要目录
```bash
sudo mkdir -p /etc/containers
```
2. 下载默认配置
```bash
# 容器注册表配置
sudo curl -o /etc/containers/registries.conf https://src.fedoraproject.org/rpms/registries.conf/raw/main/f/registries.conf

# 安全策略文件
sudo curl -o /etc/containers/policy.json https://raw.githubusercontent.com/containers/image/master/docs/containers-policy.json

# 主配置文件（替换已弃用的 libpod.conf）
sudo curl -o /etc/containers/containers.conf https://raw.githubusercontent.com/containers/common/main/docs/containers.conf
```
3. CNI 网络配置
```bash
sudo mkdir -p /etc/cni/net.d
sudo curl -o /etc/cni/net.d/87-podman-bridge.conflist https://raw.githubusercontent.com/containers/podman/main/cni/87-podman-bridge.conflist
```
## Systemd 服务配置（仅 Fedora 需要）
```bash
# 创建服务文件
cat << EOF | sudo tee /etc/systemd/system/podman.service
[Unit]
Description=Podman API Service
After=network.target

[Service]
ExecStart=/usr/bin/podman system service --time=0
Restart=always

[Install]
WantedBy=multi-user.target
EOF
```
## 启用服务
```
sudo systemctl daemon-reload
sudo systemctl enable --now podman
```
## 验证安装
```bash
# 检查版本
podman --version

# 运行测试容器
podman run --rm docker.io/hello-world:latest

# 检查网络
podman network ls
```
## 故障排除
1. OverlayFS 错误
```bash
sudo modprobe overlay
echo "overlay" | sudo tee -a /etc/modules-load.d/overlay.conf
```
2. 网络问题（替代方案）
```bash
# 创建自定义网络
podman network create mynet
podman run -d --name web --net mynet nginx:alpine
```
3. SELinux 冲突（Fedora）
```bash
sudo setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
```
## 生成 Debian 软件包（可选）
```bash
mkdir -p $HOME/riscv-podman/debs/usr/local/bin
cp /usr/local/bin/{podman,crun} $HOME/riscv-podman/debs/usr/local/bin
```
## 创建 DEBIAN 控制文件
```
cat << EOF | tee $HOME/riscv-podman/debs/DEBIAN/control
Package: podman
Version: 1.8.1
Architecture: riscv64
Maintainer: Your Name <your@email.com>
Depends: conntrack, iptables, libseccomp2
Description: Podman Container Manager
EOF
```
## 构建 deb 包
```
dpkg-deb --build $HOME/riscv-podman/debs podman-1.8.1_riscv64.deb
```
