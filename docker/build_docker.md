# 在 RISC-V 64 架构上部署 Docker（Fedora & Debian 指南）

本文提供在 RISC-V 64 位架构的 ​**Fedora**​ 和 ​**Debian**​ 系统上安装 Docker 的完整流程，包含关键差异和注意事项。

---

## ​**系统要求对比**

| 项目                | Fedora                                                                 | Debian                                                                 |
|---------------------|-----------------------------------------------------------------------|-----------------------------------------------------------------------|
| ​**推荐版本**​        | Fedora 38+                                                           | Debian 12 (Bookworm)                                                 |
| ​**内核要求**​        | 5.4+（需启用 `CONFIG_CGROUPS`, `CONFIG_OVERLAY_FS`）                  | 5.4+（需启用 `CONFIG_CGROUPS`, `CONFIG_OVERLAY_FS`）                 |
| ​**包管理器**​        | `dnf`                                                                | `apt`                                                                |
| ​**libseccomp 处理**​ | 预装 `libseccomp-devel`（若版本低需源码编译）                         | 需手动安装 `libseccomp-dev` 或源码编译                                |
| ​**SELinux**​         | 默认启用（需配置）                                                   | 无 SELinux                                                           |
| ​**cgroup 模式**​     | 默认 cgroup v2（需降级为 v1）                                        | 默认 cgroup v1                                                       |

---

## ​**通用步骤（Fedora & Debian）​**

### 1. 安装基础依赖
```bash
# Fedora
sudo dnf install -y git make golang libseccomp-devel glibc-devel

# Debian
sudo apt update && sudo apt install -y git make golang libseccomp-dev
```
### 2. 编译 libseccomp
```bash
git clone https://github.com/seccomp/libseccomp
cd libseccomp
./autogen.sh && ./configure
make && sudo make instal
```
### 3. 编译 runc
```bash
git clone https://github.com/opencontainers/runc
cd runc
make && sudo make install
```

## Fedora 专属步骤
1. 解决 SELinux 冲突
```bash
# 临时禁用 SELinux
sudo setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
```
2. 强制使用 cgroup v1
```bash
sudo grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=0"
sudo reboot
```
3. 编译 dockerd
```bash
git clone https://github.com/moby/moby
cd moby
# 指定 Go 路径（Fedora 默认 Go 可能版本低）
export PATH=/usr/local/go/bin:$PATH
make binary-daemon
sudo cp bundles/binary-daemon/dockerd /usr/local/bin/
```
​## Debian 专属步骤
1. 生成 Debian 软件包（可选）
```bash
mkdir -p $HOME/riscv-docker/debs
DESTDIR=$HOME/riscv-docker/debs make install  # 适用于各组件
dpkg-deb -b debs docker-riscv64.deb
```
3. 配置内核模块
```bash
# 检查 OverlayFS 支持
grep CONFIG_OVERLAY_FS /boot/config-$(uname -r)
sudo modprobe overlay
```
​# 服务配置（Systemd）​
1. 写入服务文件
```bash
# Fedora 服务路径
/usr/lib/systemd/system/docker.service

# Debian 服务路径
/etc/systemd/system/docker.service
```
2. 通用 Systemd 单元文件
```ini
[Unit]
Description=Docker Application Container Engine
After=network.target

[Service]
ExecStart=/usr/local/bin/dockerd --containerd=/run/containerd/containerd.sock
Restart=always

[Install]
WantedBy=multi-user.target
```
​# 验证安装
```bash
# 启动 Docker
sudo systemctl start docker
```
# 检查版本
docker --version  # 输出应有 `riscv64` 标识
​
# 常见问题
​libseccomp 不兼容​	编译时指定 --prefix=/usr	安装 libseccomp-dev 或更新至 2.5+
​cgroup 权限错误​	内核参数添加 systemd.unified_cgroup_hierarchy=0	检查 /sys/fs/cgroup 目录权限
​SELinux 阻止容器启动​	运行 sudo setenforce 0 或配置策略	无
​OverlayFS 未启用​	执行 sudo modprobe overlay	同上
​
# 替代方案
​Podman​（Fedora 优先推荐）：

```bash
sudo dnf install -y podman
podman run -it riscv64/fedora:38

```
