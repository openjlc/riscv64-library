本目录包含了riscv平台上预编译好的python第三方包

使用以下命令安装对应模块即可。
```bash
pip3 install --no-index --find-links=/path/to/dir package_name
```
安装时，--no-index参数会告诉pip从指定目录查找wheel文件，包括模块依赖的文件。若不使用该参数，pip就会从pypi查找对应的依赖模块下载并构建。
