FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 基础工具 + Mozilla PPA（容器里 snap 不可用，Firefox 必须用 deb 版）
RUN apt-get update && apt-get install -y --no-install-recommends \
      software-properties-common ca-certificates wget gnupg \
    && add-apt-repository -y ppa:mozillateam/ppa \
    && printf 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' \
       > /etc/apt/preferences.d/mozilla \
    && rm -rf /var/lib/apt/lists/*

# 桌面 + RDP + 中文输入法 + 中文字体 + 浏览器 + VSCode
RUN apt-get update && apt-get install -y --no-install-recommends \
      xfce4 xfce4-terminal thunar dbus-x11 xrdp xorgxrdp sudo \
      fcitx5 fcitx5-chinese-addons fcitx5-frontend-gtk2 \
      fcitx5-frontend-gtk3 fcitx5-frontend-qt5 im-config \
      libglib2.0-bin \
      fonts-dejavu-core fonts-noto-cjk \
      firefox \
    && rm -rf /var/lib/apt/lists/*

# Chrome（官方 deb）；root 运行必须 --no-sandbox，连系统 .desktop 一起改，
# 否则经 exo-open/应用菜单启动会静默失败
RUN apt-get update \
    && wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb \
    && apt-get install -y /tmp/chrome.deb \
    && rm /tmp/chrome.deb \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i 's|^Exec=/usr/bin/google-chrome-stable|Exec=/usr/bin/google-chrome-stable --no-sandbox|' \
       /usr/share/applications/google-chrome.desktop

# VSCode（官方 deb，宿主机经代理下载后放入构建上下文）
COPY code.deb /tmp/code.deb
RUN apt-get update \
    && apt-get install -y /tmp/code.deb \
    && rm /tmp/code.deb \
    && rm -rf /var/lib/apt/lists/* \
    && cp /usr/share/code/resources/app/resources/linux/code.png \
       /usr/share/icons/hicolor/48x48/apps/code.png \
    && gtk-update-icon-cache /usr/share/icons/hicolor/

# gnome-keyring：VSCode 等应用通过 libsecret 存令牌，缺了会弹
# "OS keyring is not available" 警告；装好后随 XDG autostart 启动
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       gnome-keyring libsecret-1-0 libsecret-tools \
    && rm -rf /var/lib/apt/lists/*

# 开发工具链：git / Node.js 22 LTS（npmmirror 官方二进制）/ uv（清华 pypi）
RUN apt-get update \
    && apt-get install -y --no-install-recommends git xz-utils python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && V=$(wget -qO- --timeout=20 "https://registry.npmmirror.com/-/binary/node/latest-v22.x/" \
          | grep -oE "node-v22\.[0-9]+\.[0-9]+-linux-x64\.tar\.gz" \
          | sed "s/-linux-x64.*//;s/node-//" | sort -t. -k2,2n -k3,3n | tail -1) \
    && wget -q --timeout=180 -O /tmp/node.tar.gz \
       "https://registry.npmmirror.com/-/binary/node/latest-v22.x/node-${V}-linux-x64.tar.gz" \
    && tar -xzf /tmp/node.tar.gz -C /usr/local --strip-components=1 \
    && rm -f /tmp/node.tar.gz \
    && pip3 install -q -i https://pypi.tuna.tsinghua.edu.cn/simple uv \
    && rm -rf /root/.cache/pip

# 与宿主机相同的 RDP 会话策略：断线即结束会话、断线重连续接原会话
RUN sed -i 's/^KillDisconnected=.*/KillDisconnected=true/' /etc/xrdp/sesman.ini \
    && sed -i 's/^Policy=.*/Policy=UBD/' /etc/xrdp/sesman.ini

RUN echo 'root:root' | chpasswd

# 桌面快捷方式模板（start.sh 在每次启动时同步到 /root/Desktop）
COPY skel/ /opt/skel/
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3389
CMD ["/start.sh"]
