# xrdp-docker-lab

在 Docker 容器里跑一个开箱即用的 XFCE 远程桌面，通过 RDP 连接，预装中文输入法和中文字体，以及 Firefox / Chrome / VSCode 和常用开发工具链。

![桌面截图](assets/screenshot.png)

## 特性

- 🖥️ **XFCE 桌面 + XRDP**：Windows 远程桌面（mstsc）或任何 RDP 客户端直连
- 🔌 **断线重连**：与宿主机相同的会话策略——断线即结束会话、重连续接原会话
- 🇨🇳 **中文开箱即用**：fcitx5 拼音输入法 + Noto CJK 字体，容器构建阶段即配置好
- 🌐 **浏览器双持**：Firefox（deb 版，经 Mozilla PPA）+ Chrome（官方 deb，已处理 root 沙箱问题）
- 📝 **VSCode**：官方 deb 安装，补齐图标并配置 gnome-keyring，不再弹 "OS keyring is not available"
- 🛠️ **开发工具链**：git、Node.js 22 LTS（npmmirror 镜像）、uv（清华 pypi 镜像）
- 💾 **数据持久化**：`/root` 挂载到宿主机目录，重建容器不丢数据；`/share` 用于宿主机↔容器交换文件

## 快速开始

### 1. 准备 VSCode 安装包

`code.deb`（约 250MB）不在仓库里，构建前需下载一次放入项目根目录。容器内访问微软官网可能超时，建议在宿主机经代理下载：

```bash
curl -x http://<你的代理地址>:7890 -sL -o code.deb \
  'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64'
```

### 2. 构建镜像

```bash
docker build -t xrdp-xfce:lab .
```

### 3. 运行容器

```bash
docker run -d --name xrdp-lab --init --shm-size=1g \
  -p 13389:3389 \
  -v /root/xrdp-docker-lab/home:/root \
  -v /root/xrdp-docker-lab/share:/share \
  xrdp-xfce:lab
```

### 4. 连接桌面

用 RDP 客户端连接 `localhost:13389`（局域网用宿主机 IP），账号 `root` / 密码 `root`。

> 首次登录后建议立即修改密码：`passwd`

### 5. 重建容器

数据都在 `home/` 目录里，重建不会丢：

```bash
docker rm -f xrdp-lab
docker run -d ...  # 同上
```

## 目录结构

```
xrdp-docker-lab/
├── Dockerfile          # 镜像定义（装什么、怎么配，全在这里）
├── start.sh            # 容器启动脚本（启 dbus/xrdp + 幂等初始化 home）
├── skel/               # 用户 home 模板，启动时同步进容器
│   ├── Desktop/        # 桌面快捷方式（Firefox / Chrome / VSCode）
│   ├── fcitx5-profile  # 输入法配置（英文键盘 + 拼音）
│   └── helpers.rc      # XFCE 首选应用（通用浏览器 → Firefox）
├── home/               # 数据卷：容器 /root 的持久化目录（git 已忽略）
└── share/              # 数据卷：宿主机↔容器文件交换（容器里挂 /share）
```

## 实现要点

- **Firefox 用 deb 而非 snap**：容器里没有 systemd，snap 不可用，改用 Mozilla PPA 并对该 PPA 设置 pin 优先级 1001 防止被 snap 过渡包顶掉。
- **Chrome 的 `--no-sandbox`**：root 运行必须加此参数，连系统 `.desktop` 文件一起改了，否则经 exo-open / 应用菜单启动会静默失败。
- **会话策略**：`sesman.ini` 设置 `KillDisconnected=true` + `Policy=UBD`，断线即结束会话、重连续接原会话。
- **home 幂等初始化**：`start.sh` 每次启动检查并补齐 `.xinputrc`、fcitx5 配置、桌面快捷方式（含 `gio set metadata::trusted`），数据卷重建后无需手工配置。

## License

[MIT](LICENSE)
