# Ghidra 下载说明

此目录只保存说明文件。仓库不包含 Ghidra 安装包、分卷或解压后的程序。
Docker 首次构建时会自动从官方地址下载 Ghidra 12.1.4，校验 SHA-256 后解压到
镜像内的 `/opt/ghidra/current`，用户无需手动准备 Ghidra。

- [官方下载 ZIP：ghidra_12.1.4_PUBLIC_20260921.zip](https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip)
- [官方发布页面](https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_12.1.4_build)
- ZIP 大小：569,649,598 字节，约 543 MiB。
- SHA-256：`ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db`

版本、发布日期和完整性校验固定在项目 `Dockerfile` 中。下载完成后会删除镜像
内的临时 ZIP，最终镜像保留解压后的 Ghidra 本体。

首次构建需要能访问 GitHub Release 下载地址。网络需要代理时，可在 `.env`
配置 `BUILD_HTTP_PROXY` 和 `BUILD_HTTPS_PROXY`；Docker Desktop 访问宿主机
代理通常使用 `http://host.docker.internal:端口`。

手动下载仅用于独立使用或留存。请将安装包和解压目录放在项目外；即使放入本目录，
也会被 Git 和 Docker 构建上下文忽略，不会改变 Docker 的自动下载流程。
Ghidra 自身保留上游许可证和第三方声明，独立于本项目的 MIT 许可证。
