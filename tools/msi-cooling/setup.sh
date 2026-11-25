#!/bin/bash
# Run without sudo in Jestin's desktop terminal; elevation is limited to installation.
set -euo pipefail
export PATH=/usr/bin:/bin
setup_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ ${1:-} != --system ]]; then
  [[ $# == 0 && $EUID != 0 && $(id -un) == jestin ]] || {
    echo "Run this without sudo from Jestin's desktop terminal." >&2; exit 1;
  }
  printf '%s\n' 'Installing Quiet, Balanced, Boost and Dynamic cooling.' \
    'Dynamic is the initial mode. The service manages fans and the CPU power profile.' \
    'The active local jestin session can select only fixed cooling operations.'
  sudo /usr/bin/bash "$setup_dir/setup.sh" --system
  hyprctl reload
  errors=$(hyprctl configerrors)
  if [[ -n $errors && $errors != 'ok' ]]; then
    printf 'Hyprland configuration errors:\n%s\n' "$errors" >&2
    exit 1
  fi
  /home/jestin/.local/bin/msi-cooling status
  printf '%s\n' 'Fn+F7 / Super+F7: cycle Quiet -> Balanced -> Dynamic -> Boost -> Quiet.' \
    'Super+Shift+F7: cycle modes. Super+Ctrl+F7: Dynamic. Super+Alt+F7: status.' \
    'If Fn+F7 has not worked since the initial mapping, save work and log out/in once.' \
    'To return control to firmware/Omarchy: sudo systemctl disable --now msi-cooling.service'
  exit
fi
[[ $# == 1 && $EUID == 0 && ${SUDO_USER:-} == jestin ]] || exit 1
[[ $(cat /sys/class/dmi/id/product_name) == 'GF63 Thin 11UC' ]] || {
  echo 'This setup is scoped to the GF63 Thin 11UC.' >&2; exit 1;
}
[[ -e /sys/devices/platform/msi-ec/cooler_boost ]] || {
  echo 'The msi-ec Cooler Boost control is missing.' >&2; exit 1;
}
busctl --system get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile >/dev/null
sources=(controller.py msi-cooling.service local.msi.cooling.policy 49-msi-cooling.rules 90-msi-gf63-cooling.hwdb legacy-toggle)
targets=(/usr/local/libexec/msi-cooling-controller /etc/systemd/system/msi-cooling.service /usr/share/polkit-1/actions/local.msi.cooling.policy /etc/polkit-1/rules.d/49-msi-cooling.rules /etc/udev/hwdb.d/90-msi-gf63-cooling.hwdb /usr/local/libexec/msi-cooler-boost-toggle)
for source in "${sources[@]}"; do [[ -f $setup_dir/$source ]] || { echo "Missing $source" >&2; exit 1; }; done
python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$setup_dir/controller.py"
xmllint --noout "$setup_dir/local.msi.cooling.policy"
install -d -o root -g root -m 0755 /var/lib/msi-cooling
backup_dir=$(mktemp -d /var/lib/msi-cooling/install-backup.XXXXXX)
for i in "${!sources[@]}"; do
  if [[ -e ${targets[i]} || -L ${targets[i]} ]]; then
    cp -a -- "${targets[i]}" "$backup_dir/${sources[i]}"
  fi
done
for i in "${!sources[@]}"; do
  mode=0644
  [[ $i == 0 || $i == 5 ]] && mode=0755
  install -D -o root -g root -m "$mode" "$setup_dir/${sources[i]}" "${targets[i]}"
done
systemd-analyze verify /etc/systemd/system/msi-cooling.service
systemd-hwdb update
udevadm control --reload
udevadm trigger --action=change --subsystem-match=input --sysname-match='event*' --settle
systemctl daemon-reload
systemctl enable msi-cooling.service
systemctl restart msi-cooling.service
for attempt in {1..20}; do
  if python3 -c 'import json,time; v=json.load(open("/run/msi-cooling/status.json")); assert time.time()-v["updated"]<10 and not v.get("error")' 2>/dev/null; then
    printf 'Controller running. Previous system files saved in %s\n' "$backup_dir"
    exit 0
  fi
  sleep 1
done
journalctl -u msi-cooling.service -n 12 --no-pager
echo 'Controller did not report a healthy state; inspect the output above.' >&2
exit 1
