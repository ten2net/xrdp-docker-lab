#!/bin/bash
set -e

mkdir -p /run/xrdp
rm -f /run/xrdp/*.pid

# dbus 是 xfce4-session 和 xrdp 桌面启动的必要条件（容器里没有 systemd）
service dbus start

# ---- home 初始化（/root 可能是挂载的数据卷，每次启动幂等补齐）----
mkdir -p /root/Desktop /root/.config/fcitx5 /share

# 默认输入法框架：fcitx5（run_im 由 Xsession.d 的 im-config 钩子提供，
# 阶段1注入 GTK_IM_MODULE 等环境变量，阶段2拉起 fcitx5 守护进程）
if [ ! -f /root/.xinputrc ]; then
  echo 'run_im fcitx5' > /root/.xinputrc
fi

# fcitx5 配置：英文键盘 + 拼音
if [ ! -f /root/.config/fcitx5/profile ]; then
  cp /opt/skel/fcitx5-profile /root/.config/fcitx5/profile
fi

# 通用浏览器助手（exo-open --launch WebBrowser 用）。
# root 下 Chrome 无 --no-sandbox 起不来，这里用 Firefox 保底。
mkdir -p /root/.config/xfce4
if [ ! -f /root/.config/xfce4/helpers.rc ]; then
  cp /opt/skel/helpers.rc /root/.config/xfce4/helpers.rc
fi

# 桌面快捷方式
cp /opt/skel/Desktop/*.desktop /root/Desktop/ 2>/dev/null || true
chmod +x /root/Desktop/*.desktop 2>/dev/null || true
for f in /root/Desktop/*.desktop; do
  [ -e "$f" ] && gio set "$f" metadata::trusted true 2>/dev/null || true
done

/usr/sbin/xrdp-sesman
exec /usr/sbin/xrdp -nodaemon
