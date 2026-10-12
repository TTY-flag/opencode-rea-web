# OpenCode REA Web

把文件放好，填入模型地址、API Key 和模型名，启动后直接在浏览器里对话。

项目直接运行 **`opencode web`**，内置 REA MCP、匹配的 REA Skill 和 Ghidra
Headless。没有额外的 Web Server，也不要求 Web 登录密码。

## 三步开始

准备 Docker；Windows 使用 Docker Desktop 的 **Linux 容器**模式。初次启动会
构建镜像并安装依赖，需要联网，建议给 Docker 分配至少 8 GB 内存。完整的
Ghidra 发行包已包含在仓库中，clone 后无需单独下载 Ghidra。

**1. 放文件。** 把待分析的文件或目录复制到 `workspace/`。也可以在下一步
把 `WORKSPACE_DIR` 改为已经存在的目录，不必复制。

**2. 配模型。** 将 `.env.example` 复制为 `.env`，填写三个字段：

```dotenv
MODEL_BASE_URL=https://你的模型服务地址/v1
MODEL_API_KEY=你的APIKey
MODEL_ID=你的模型名
```

这里需要支持工具调用的 **OpenAI 兼容 Chat Completions 接口**。模型名填写
服务提供商的实际 ID；例如路由服务的模型名可以包含 `/`。接口地址填写 API
前缀，不要追加 `/chat/completions`。本地无认证模型也需给 `MODEL_API_KEY`
填一个非空占位值，例如 `local`。模型与 Web 服务是不同配置，无需填写 Web 密码。

**3. 启动。** 在项目目录执行：

Windows PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

Linux / macOS：

```bash
bash start.sh
```

脚本等待服务健康后显示地址；Windows 会自动打开浏览器。默认地址是
**http://localhost:4096**。在 OpenCode 中打开 `/workspace` 项目，然后开始对话：

> 使用 REA 的 Ghidra 后端，静态分析 /workspace/1.exe。先看概览、关键字符串和
> 入口函数，解释主要功能，把带函数地址和证据的报告保存到 /workspace/analysis。

熟悉 Docker 的用户也可以直接启动：

```bash
docker compose up -d --build --wait
```

## 文件和会话

- 宿主机分析目录以 **可读写** 方式挂载到 `/workspace`，写入会直接反映到宿主机。
- 报告和证据默认写到 `workspace/analysis/`，重建代码写到 `workspace/reconstructed/`。
- OpenCode 会话使用 Compose 持久卷；`docker compose down` 保留这些数据。
- `docker compose down -v` 会删除持久卷中的会话和缓存，工作目录中的文件仍然保留。
- `.env`、分析样本和分析输出已经被 `.gitignore` 排除，不会随项目提交。
- 一个 REA 连接保持一个活动二进制；同一项目的多个聊天不要交错分析不同文件。
  多文件任务按顺序处理，并在关闭目标前导出证据。

Windows 的现有目录配置示例：

```dotenv
WORKSPACE_DIR=D:/samples/my-app
```

挂载的目录必须已经存在。目录映射到 **Docker 所在机器**；浏览器打开服务不会
自动上传浏览器所在电脑的文件。

## 内置工具

| 组件 | 固定版本 / 用途 |
| --- | --- |
| Ubuntu | 24.04，Linux amd64 |
| Node.js | 24.11.1，运行 REA |
| OpenCode | 1.19.0，提供 Web 和 Agent |
| REA | 6.4.0，MCP、CLI、配套 Skill |
| Ghidra | 12.1.4，完整 Linux JDK 21 |
| 常用工具 | Python 3、Git、ripgrep、file、binutils、jq、GCC/G++、make、解压工具 |

Node 下载和内置 Ghidra 解包都会校验 SHA-256。原生 EXE/DLL、ELF 等通过 Ghidra 静态分析；
JavaScript/Electron 和 .NET 的静态检查使用 REA 自带能力。REA 工具列表中需要
其他引擎的功能不等于已经可用：本镜像没有安装 JADX、IDA、Hopper、浏览器或固件
引擎。Linux 容器可以分析 Windows PE，但不会因此具备原生 Windows 运行环境。

## 可选配置

通常只需填写三个模型字段。下面的变量按需添加到 `.env`：

| 变量 | 默认值 | 用途 |
| --- | --- | --- |
| `WEB_PORT` | `4096` | 宿主机 Web 端口 |
| `BIND_ADDRESS` | `127.0.0.1` | 改为 `0.0.0.0` 可供可信内网团队访问 |
| `MODEL_API` | `openai-compatible` | Responses API 使用 `openai-responses` |
| `MODEL_CONTEXT` / `MODEL_OUTPUT` | `131072` / `16384` | 按模型实际 token 规格设置 |
| `MODEL_TEMPERATURE` / `MODEL_TOP_P` | 空 | Build / Plan 主对话采样参数；空值使用默认值 |
| `MODEL_REASONING_EFFORT` | 空 | 模型支持时可设 `low`、`medium`、`high`、`xhigh`、`max` |
| `APP_UID` / `APP_GID` | `1000` / `1000` | Linux 宿主机使用 `id -u` / `id -g` 的结果 |
| `CPU_LIMIT` / `MEMORY_LIMIT` | `4` / `8g` | 容器资源上限 |
| `GHIDRA_HEADLESS_MAXMEM` | `2G` | Ghidra JVM 堆大小 |
| `REA_GHIDRA_STARTUP_TIMEOUT_MS` | `600000` | 引擎首次分析等待时间 |
| `MCP_TIMEOUT_MS` | `900000` | OpenCode 等待 REA 工具的时间 |
| `BUILD_HTTP_PROXY` / `BUILD_HTTPS_PROXY` | 空 | 构建下载时使用的代理 |
| `RUNTIME_HTTP_PROXY` / `RUNTIME_HTTPS_PROXY` | 空 | 模型调用等运行时代理 |

Docker Desktop 使用宿主机服务时，可填写 `host.docker.internal`，例如
`MODEL_BASE_URL=http://host.docker.internal:1234/v1`。容器里的 `localhost`
指向容器自身。代理也需使用容器能够访问的地址。

修改 `.env` 后重新运行启动脚本即可。模型 Key 不写入镜像；生成的 OpenCode
配置通过环境变量引用 Key。Web 默认无密码，适用于本机或可信网络。

### MiniMax 配置示例

截至 2026-10-12，[官方模型列表](https://platform.minimax.cn/docs/guides/text-generation)
提供以下选择：

| 模型 ID | 上下文 | 选择建议 |
| --- | --- | --- |
| `MiniMax-M3.1-Flash-Preview` | 1,000,000 | 最新预览型号，可调思考深度；复杂分析可尝试 `max` |
| `MiniMax-M3` | 1,000,000 | 正式型号，代码与工具任务；不支持调节 `reasoning_effort` |
| `MiniMax-M2.7` | 204,800 | 已验证的上一代选择 |
| `MiniMax-M2.7-highspeed` | 204,800 | 官方说明效果与 M2.7 相同、输出更快 |

M3.1 预览版官方目前主要通过 M Plan / MiniMax Code 提供，是否可用以你的 Key
实际权限为准。更早的 M2.5、M2.1 和 M2 仍列在官方历史模型中。

使用 M3.1 的示例，Key 填自己的：

```dotenv
MODEL_BASE_URL=https://api.minimax.cn/v1
MODEL_API_KEY=你的APIKey
MODEL_ID=MiniMax-M3.1-Flash-Preview
MODEL_CONTEXT=1000000
MODEL_OUTPUT=32000
MODEL_TEMPERATURE=1
MODEL_TOP_P=0.95
MODEL_REASONING_EFFORT=max
```

`MODEL_CONTEXT` 告诉 OpenCode 模型实际上下文容量，不会自动上传整个目录。
`MODEL_OUTPUT` 是每次模型回复的 token 上限，包含思考内容；本项目的 OpenCode
1.19.0 默认还会将实际输出上限限制在 32,000。上面的 32,000 是项目配置选择，
不是模型的官方最大输出声明。

MiniMax M3 / M3.1 的 API 默认温度为 `1`、`top_p` 为 `0.95`；一般可以沿用。
M3.1 的思考深度默认 `max`，降低档位会减少耗时和思考 token；`none` 不可用。
容器会为 M3.1 配置五档 OpenCode variant，并保留工具多轮历史中的
`reasoning_content`。切换为 M3 或 M2.x 时删除 `MODEL_REASONING_EFFORT`，它们
没有同样的五档调节能力。已有会话也要在 Web 模型选择器中切换到新型号。
参数和兼容性以 [MiniMax API 文档](https://platform.minimax.cn/docs/api-reference/text-openai-api)
为准；采样参数不是提高准确率的保证，分析结论仍需函数地址和工具证据支撑。

## 查看和停止

```bash
docker compose ps
docker compose logs -f app
docker compose exec app opencode mcp list
docker compose down
```

启动脚本会先检查模型字段、工作目录写权限及 Ghidra 环境。`rea connected`
只代表 MCP 连通，首次 Ghidra 查询还需要导入和自动分析。

如果出现目录无法写入，检查 `WORKSPACE_DIR` 和 UID/GID。如果连接模型失败，
检查 API 前缀、Key、模型 ID、模型的工具调用支持及容器网络。如果端口被占用，
修改 `WEB_PORT`；Ghidra 分析超时时再调整上面的两个等待时间。

## 验证镜像

启动后可运行真实静态反编译检查；它不会执行目标文件：

```bash
docker compose exec app node /opt/rea-web/tests/smoke.cjs
# 或验证自己的样本：
docker compose exec app node /opt/rea-web/tests/smoke.cjs /workspace/1.exe
```

检查会获取函数和伪代码，导出证据，确认原文件哈希未变并关闭会话。
结果保存在 `workspace/analysis/verification-*/`。

2026-10-12 已验证：Linux/amd64 镜像构建、无密码 Web 页面、可写挂载、REA MCP
工具回路，以及真实 Windows x64 PE 样本的 Ghidra 反编译。另使用 MiniMax-M2.7
完成了 OpenCode → REA → Ghidra → 写入伪代码 → 关闭会话的真实模型验收。
MiniMax-M3.1-Flash-Preview 的 `max` 档也已通过同样的真实工具验收；独立协议测试
确认采样和思考参数到达接口，工具多轮历史保留 `reasoning_content`。
测试样本、模型 Key 和本机测试输出均不随仓库提交。

## 项目结构

```text
Dockerfile          # 工具安装，固定版本与下载校验
compose.yaml        # 端口、可写挂载、持久卷、资源设置
.env.example        # 模型配置模板
entrypoint.sh       # 自动生成配置，最后 exec opencode web
instructions.md     # 工作目录和分析方式的默认指引
start.ps1 / start.sh # 一键启动
workspace/          # 用户文件，Git 忽略
tests/              # 实际反编译验收
vendor/ghidra/      # 完整官方 Ghidra 发行包及校验信息
```

Ghidra 官方 ZIP 约 543 MiB，仓库以 12 个分卷保存，每卷最多 48 MiB，避免触发
GitHub 的单文件限制。使用普通 `git clone` 即可取得全部分卷，不需要 Git LFS；
Docker 构建自动合并、校验和解包。安装后的最终镜像不保留这些分卷。
基础 Ubuntu 镜像、apt 和 npm 依赖仍需在首次构建时联网获取。

项目代码采用 MIT 许可证。镜像内各上游工具保留各自的许可证和第三方声明。
上游：[OpenCode](https://opencode.ai/) · [REA](https://github.com/morluto/rea) ·
[Ghidra](https://github.com/NationalSecurityAgency/ghidra)。
