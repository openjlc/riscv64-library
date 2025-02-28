# 在 RISC-V 虚拟机或单板计算机上构建 Go 语言指南

## 背景说明
Go 语言已官方支持 RISC-V 架构，但未提供预编译二进制包。需通过以下步骤从源码构建，您需要先在其他架构主机上生成引导环境（Bootstrap），然后将引导包传输至 RISC-V 设备进行完整构建。

---

## 步骤说明（双阶段构建流程）

### 阶段一：生成引导包（在 x86/ARM 等主机执行）

1. 克隆 Go 源码库
```   
git clone https://github.com/golang/go
cd go/src
```
2. 生成 RISC-V 引导包（支持跨平台编译）
```
GOOS=linux GOARCH=riscv64 ./bootstrap.bash
```
3. 传输引导包至 RISC-V 设备（示例使用本地虚拟机）
```
scp -P 22222 ../../go-linux-riscv64-bootstrap.tbz root@localhost:/
```
### 阶段二：完整构建（在 RISC-V 设备执行）
1. 解压引导包
```
tar jxvf go-linux-riscv64-bootstrap.tbz  # 修正：补充解压参数 -j
```
2. 获取最新 Go 源码
```
git clone https://github.com/golang/go
cd go
```
3. 同步最新稳定版标签
```
git fetch --tags  # 新增：确保获取全部标签
git checkout $(git describe --tags)
```
4. 配置构建环境
```
cd src
export GOROOT_BOOTSTRAP=$HOME/go-linux-riscv64-bootstrap
```
# 5. 执行完整构建
```
./make.bash
```
# 6. 运行测试套件（延长超时阈值）
```
GO_TEST_TIMEOUT_SCALE=10 ./run.bash
```
7. 打包生成文件（排除中间文件）
```
cd ../..
tar -cvf go-$(git describe --tags).linux-riscv64.tar \
  --exclude=pkg/obj \
  --exclude=.git \
  --exclude=testdata  go  # 新增：排除测试数据
```
## 关键要点说明
1. 解压参数修正
​原文档问题：.tbz 文件需用 bzip2 解压
​修正建议：
```bash
tar jxvf go-linux-riscv64-bootstrap.tbz
```
2. 依赖项要求
```bash
# RISC-V 设备需预装：
sudo apt install git build-essential bzip2
```
3. 构建优化建议
并行编译加速：
```bash
./make.bash -j $(nproc)
```
4. 内存不足处理：
```bash
export GOFLAGS="-ldflags=-compressdwarf=false"
```
5. 预编译包替代方案
从 Go 官方二进制分发页 下载 linux/riscv64 包（若有），无需完整构建：
```
bash
wget https://go.dev/dl/go1.21.0.linux-riscv64.tar.gz
tar -C /usr/local -xzf go*.tar.gz
```
## 验证流程
```
go version
#$ 输出应包含 "linux/riscv64"
```
# 运行跨架构测试
cat > hello.go <<EOF
package main
import "fmt"
func main() { fmt.Println("RISC-V Go Works!") }
EOF
go run hello.go
技术文档修正对照表
原文档内容	问题描述	修正方案
tar vxf	缺少解压参数	改为 tar jxvf
git describe --tags	可能缺失最新标签	增加 git fetch --tags
未声明构建依赖	可能缺失编译工具链	添加 apt 安装步骤
未优化编译参数	构建时间较长	添加 -j $(nproc) 并行编译参数
undefined
