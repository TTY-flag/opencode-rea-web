# Ghidra 下载说明

请先下载 Ghidra 12.1.4 官方 ZIP，按原文件名放到本目录，**无需解压**。
Docker 构建时读取本地 ZIP，校验 SHA-256 后解压到镜像内的
`/opt/ghidra/current`。Ghidra 的准备由用户完成，Docker 不下载 Ghidra。

- [官方下载 ZIP：ghidra_12.1.4_PUBLIC_20260921.zip](https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip)
- [官方发布页面](https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_12.1.4_build)
- ZIP 大小：569,649,598 字节，约 543 MiB。
- SHA-256：`ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db`

放好后的目录结构：

```text
vendor/ghidra/
├── README.md
└── ghidra_12.1.4_PUBLIC_20260921.zip
```

下载后填写项目 `.env`，运行 `start.ps1` 或 `start.sh`。缺少安装包时，启动脚本
会显示下载地址和放置位置。请使用上面固定版本的官方文件并保留完整文件名；
重新压缩的 ZIP 无法通过完整性校验。更新 Ghidra 版本时，需要同时更新
`Dockerfile`、`.dockerignore`、两个启动脚本和本说明中的文件名及 SHA-256。

Git 只跟踪本目录的 `README.md`，ZIP 会被 `.gitignore` 排除；Docker 构建上下文
只允许上述 ZIP。最终镜像保留解压后的 Ghidra 本体，并删除镜像内的临时 ZIP；
宿主机本目录的 ZIP 会保留供后续构建使用。其他基础镜像和软件依赖首次构建仍需联网。
Ghidra 自身保留上游许可证和第三方声明，独立于本项目的 MIT 许可证。
