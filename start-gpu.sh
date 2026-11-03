#!/bin/bash
set -e

mkdir -p /run/xrdp
rm -f /run/xrdp/*.pid

# dbus 是 GNOME 会话和 xrdp 桌面启动的必要条件（容器里没有 systemd）
service dbus start

# GNOME Shell 42 的 LoginManager 强制依赖 org.freedesktop.login1（无 elogind，
# jammy 源里没有），以独立模式拉起 systemd-logind 提供该 D-Bus 服务。
# 注意：容器里 logind 不会自行 daemonize，必须后台拉起，否则阻塞后续 xrdp 启动
mkdir -p /run/systemd
pgrep -x systemd-logind >/dev/null || { /lib/systemd/systemd-logind & }

# ---- home 初始化（/root 可能是挂载的数据卷，每次启动幂等补齐）----
mkdir -p /root/Desktop /root/.config/fcitx5 /share

# GNOME on Xorg：容器里没有 systemd/logind，显式声明 X11 会话，
# 否则 GNOME 会按 Wayland/systemd 路径启动直接失败
mkdir -p /run/user/0
chmod 700 /run/user /run/user/0
# 每次启动重写（非用户配置文件，内容受镜像版本控制，避免旧卷沿用缺失变量的历史版本）
cat > /root/.xsessionrc <<'EOF'
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export DESKTOP_SESSION=ubuntu
export GNOME_SHELL_SESSION_MODE=ubuntu
# 没有 pam_systemd 创建运行期目录，gnome-shell 缺了会直接退出
export XDG_RUNTIME_DIR=/run/user/0
# 会话级保底：gnome-terminal 在非 UTF-8 locale 下拒绝启动
export LANG=zh_CN.UTF-8
EOF

# 默认输入法框架：fcitx5（run_im 由 Xsession.d 的 im-config 钩子提供，
# 阶段1注入 GTK_IM_MODULE 等环境变量，阶段2拉起 fcitx5 守护进程）
if [ ! -f /root/.xinputrc ]; then
  echo 'run_im fcitx5' > /root/.xinputrc
fi

# fcitx5 配置：英文键盘 + 拼音
if [ ! -f /root/.config/fcitx5/profile ]; then
  cp /opt/skel/fcitx5-profile /root/.config/fcitx5/profile
fi

# GNOME 默认浏览器：root 下 Chrome 无 --no-sandbox 起不来，用 Firefox 保底
if [ ! -f /root/.config/mimeapps.list ]; then
  printf '[Default Applications]\nx-scheme-handler/http=firefox.desktop\nx-scheme-handler/https=firefox.desktop\ntext/html=firefox.desktop\n' \
    > /root/.config/mimeapps.list
fi

# 桌面快捷方式（通用模板 + GPU 版专属）
cp /opt/skel/Desktop/*.desktop /root/Desktop/ 2>/dev/null || true
cp /opt/skel-gpu/Desktop/*.desktop /root/Desktop/ 2>/dev/null || true
chmod +x /root/Desktop/*.desktop 2>/dev/null || true
for f in /root/Desktop/*.desktop; do
  [ -e "$f" ] && gio set "$f" metadata::trusted true 2>/dev/null || true
done

/usr/sbin/xrdp-sesman
exec /usr/sbin/xrdp -nodaemon
