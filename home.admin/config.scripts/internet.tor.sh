#!/bin/bash

# Background:
# https://medium.com/@lopp/how-to-run-bitcoin-as-a-tor-hidden-service-on-ubuntu-cff52d543756
# https://bitcoin.stackexchange.com/questions/70069/how-can-i-setup-bitcoin-to-be-anonymous-with-tor
# https://github.com/lightningnetwork/lnd/blob/master/docs/configuring_tor.md

# INFO
# --------------------
# basic install of Tor is done by the build script now .. on/off will just switch service on/off
# also thats where the sources are set and the preparation is done

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
 echo "script to switch Tor on or off"
 echo "internet.tor.sh [status|on|off|btcconf-on|btcconf-off|update]"
 exit 1
fi

torrc="/etc/tor/torrc"

activateBitcoinOverTOR()
{
  echo "*** Changing ${network} Config ***"

  btcExists=$(sudo ls /home/bitcoin/.${network}/${network}.conf | grep -c "${network}.conf")
  if [ ${btcExists} -gt 0 ]; then

    # make sure all is turned off and removed and then activate fresh (so that also old settings get removed)
    deactivateBitcoinOverTOR

    sudo chmod 777 /home/bitcoin/.${network}/${network}.conf
    echo "Adding Tor config to the the ${network}.conf ..."
    sudo sed -i "s/^torpassword=.*//g" /home/bitcoin/.${network}/${network}.conf
    echo "onlynet=onion" >> /home/bitcoin/.${network}/${network}.conf
    echo "proxy=127.0.0.1:9050" >> /home/bitcoin/.${network}/${network}.conf
    echo "main.bind=127.0.0.1" >> /home/bitcoin/.${network}/${network}.conf
    echo "test.bind=127.0.0.1" >> /home/bitcoin/.${network}/${network}.conf
    echo "dnsseed=0" >> /home/bitcoin/.${network}/${network}.conf
    echo "dns=0" >> /home/bitcoin/.${network}/${network}.conf

    # remove empty lines
    sudo sed -i '/^ *$/d' /home/bitcoin/.${network}/${network}.conf
    sudo chmod 664 /home/bitcoin/.${network}/${network}.conf

    # copy new bitcoin.conf to admin user for cli access
    sudo cp /home/bitcoin/.${network}/${network}.conf /home/admin/.${network}/${network}.conf
    sudo chown admin:admin /home/admin/.${network}/${network}.conf

  else
    echo "BTC config does not found (yet) -  try with 'internet.tor.sh btcconf-on' again later" 
  fi
}

deactivateBitcoinOverTOR()
{
  # always make sure also to remove old settings
  sudo sed -i "s/^onlynet=.*//g" /home/bitcoin/.${network}/${network}.conf
  sudo sed -i "s/^main.addnode=.*//g" /home/bitcoin/.${network}/${network}.conf
  sudo sed -i "s/^test.addnode=.*//g" /home/bitcoin/.${network}/${network}.conf
  sudo sed -i "s/^proxy=.*//g" /home/bitcoin/.${network}/${network}.conf
  sudo sed -i "s/^main.bind=.*//g" /home/bitcoin/.${network}/${network}.conf
  sudo sed -i "s/^test.bind=.*//g" /home/bitcoin/.${network}/${network}.conf
  sudo sed -i "s/^dnsseed=.*//g" /home/bitcoin/.${network}/${network}.conf
  sudo sed -i "s/^dns=.*//g" /home/bitcoin/.${network}/${network}.conf
  # remove empty lines
  sudo sed -i '/^ *$/d' /home/bitcoin/.${network}/${network}.conf
  sudo cp /home/bitcoin/.${network}/${network}.conf /home/admin/.${network}/${network}.conf
  sudo chown admin:admin /home/admin/.${network}/${network}.conf
}

# check and load raspiblitz config
# to know which network is running
if [ -f "/home/admin/raspiblitz.info" ]; then
  source /home/admin/raspiblitz.info
fi

if [ -f "/mnt/hdd/raspiblitz.conf" ]; then
  source /mnt/hdd/raspiblitz.conf
fi

torRunning=$(sudo systemctl --no-pager status tor@default | grep -c "Active: active")
torFunctional=$(curl --connect-timeout 30 --socks5-hostname "127.0.0.1:9050" https://check.torproject.org 2>/dev/null | grep -c "Congratulations. This browser is configured to use Tor.")
if [ "${torFunctional}" == "" ]; then torFunctional=0; fi
if [ ${torFunctional} -gt 1 ]; then torFunctional=1; fi

# if started with status
if [ "$1" = "status" ]; then
  # is Tor activated
  if [ "${runBehindTor}" == "on" ]; then
    echo "activated=1"
  else
    echo "activated=0"
  fi
  echo "torRunning=${torRunning}"
  echo "torFunctional=${torFunctional}"
  echo "config='${torrc}'"
  exit 0
fi

# if started with btcconf-on 
if [ "$1" = "btcconf-on" ]; then
  activateBitcoinOverTOR
  exit 0
fi

# if started with btcconf-off
if [ "$1" = "btcconf-off" ]; then
  deactivateBitcoinOverTOR
  exit 0
fi

# add default value to raspi config if needed
checkTorEntry=$(sudo cat /mnt/hdd/raspiblitz.conf | grep -c "runBehindTor")
if [ ${checkTorEntry} -eq 0 ]; then
  echo "runBehindTor=off" >> /mnt/hdd/raspiblitz.conf
fi

# location of TOR config
# make sure /etc/tor exists
sudo mkdir /etc/tor 2>/dev/null

if [ "$1" != "update" ]; then 
  # stop services (if running)
  echo "making sure services are not running"
  sudo systemctl stop lnd 2>/dev/null
  sudo systemctl stop ${network}d 2>/dev/null
  sudo systemctl stop tor@default 2>/dev/null
fi

# switch on
if [ "$1" = "1" ] || [ "$1" = "on" ]; then
  echo "# switching Tor ON"

  # *** CURL TOR PROXY ***
  # see https://github.com/rootzoll/raspiblitz/issues/1341
  #echo "socks5-hostname localhost:9050" > .curlrc.tmp
  #sudo cp ./.curlrc.tmp /root/.curlrc
  #sudo chown root:root /home/admin/.curlrc
  #sudo cp ./.curlrc.tmp /home/pi/.curlrc
  #sudo chown pi:pi /home/pi/.curlrc
  #sudo cp ./.curlrc.tmp /home/admin/.curlrc
  #sudo chown admin:admin /home/admin/.curlrc
  #rm .curlrc.tmp

  # make sure the network was set (by sourcing raspiblitz.conf)
  if [ ${#network} -eq 0 ]; then
    echo "!! FAIL - unknown network due to missing /mnt/hdd/raspiblitz.conf"
    echo "# switching Tor config on for RaspiBlitz services is just possible after basic hdd/ssd setup"
    echo "# but with new 'Tor by default' basic Tor socks will already be available from the start"
    exit 1
  fi

  # setting value in raspi blitz config
  sudo sed -i "s/^runBehindTor=.*/runBehindTor=on/g" /mnt/hdd/raspiblitz.conf

  # install package just in case it was deinstalled
  packageInstalled=$(dpkg -s tor-arm | grep -c 'Status: install ok')
  if [ ${packageInstalled} -eq 0 ]; then
    sudo apt install tor tor-arm torsocks -y
  fi

  # create tor data directory if it not exist
  if [ ! -d "/mnt/hdd/tor" ]; then
    echo "# - creating tor data directory"
    sudo mkdir -p /mnt/hdd/tor
    sudo mkdir -p /mnt/hdd/tor/sys
  else
    echo "# - tor data directory exists"
  fi
  # make sure its the correct owner
  sudo chmod -R 700 /mnt/hdd/tor
  sudo chown -R debian-tor:debian-tor /mnt/hdd/tor

  # create tor config .. if not exists or is old
  isTorConfigOK=$(sudo cat /etc/tor/torrc 2>/dev/null | grep -c "Bitcoin")
  if [ ${isTorConfigOK} -eq 0 ]; then
    echo "# - updating Tor config ${torrc}"
    cat > ./torrc <<EOF
### torrc for tor@default
### See 'man tor', or https://www.torproject.org/docs/tor-manual.html

DataDirectory /mnt/hdd/tor/sys
PidFile /mnt/hdd/tor/sys/tor.pid

SafeLogging 0
Log notice stdout
Log notice file /mnt/hdd/tor/notice.log
Log info file /mnt/hdd/tor/info.log

RunAsDaemon 1
ControlPort 9051
SocksPort 9050
ExitRelay 0
CookieAuthentication 1
CookieAuthFileGroupReadable 1

# Hidden Service for WEB ADMIN INTERFACE
HiddenServiceDir /mnt/hdd/tor/web80/
HiddenServiceVersion 3
HiddenServicePort 80 127.0.0.1:80

# NOTE: since Bitcoin Core v0.21.0 sets up a v3 Tor service automatically 
# see /mnt/hdd/bitcoin for the onion private key - delete and restart bitcoind to reset

# NOTE: LND onion private key at /mnt/hdd/lnd/v3_onion_private_key

# Hidden Service for LND RPC
HiddenServiceDir /mnt/hdd/tor/lndrpc10009/
HiddenServiceVersion 3
HiddenServicePort 10009 127.0.0.1:10009

# Hidden Service for LND REST
HiddenServiceDir /mnt/hdd/tor/lndrest8080/
HiddenServiceVersion 3
HiddenServicePort 8080 127.0.0.1:8080
EOF
    sudo rm $torrc
    sudo mv ./torrc $torrc
    sudo chmod 644 $torrc
    sudo chown -R debian-tor:debian-tor /var/run/tor/ 2>/dev/null
    echo ""

    sudo mkdir -p /etc/systemd/system/tor@default.service.d
    sudo tee /etc/systemd/system/tor@default.service.d/raspiblitz.conf >/dev/null <<EOF
    # DO NOT EDIT! This file is generated by raspiblitz and will be overwritten
[Service]
ReadWriteDirectories=-/mnt/hdd/tor
[Unit]
After=network.target nss-lookup.target mnt-hdd.mount
EOF

  else
    echo "# - Tor config ${torrc} is already updated"
  fi

  # ACTIVATE TOR SERVICE
  echo "*** Enable Tor Service ***"
  sudo systemctl daemon-reload
  sudo systemctl enable tor@default
  echo ""

  # ACTIVATE BITCOIN OVER TOR (function call)
  activateBitcoinOverTOR

  # ACTIVATE APPS OVER TOR
  source /mnt/hdd/raspiblitz.conf 2>/dev/null
  if [ "${BTCRPCexplorer}" = "on" ]; then
    /home/admin/config.scripts/internet.hiddenservice.sh btc-rpc-explorer 80 3022 443 3023
  fi
  if [ "${rtlWebinterface}" = "on" ]; then
    /home/admin/config.scripts/internet.hiddenservice.sh RTL 80 3002 443 3003
  fi
  if [ "${BTCPayServer}" = "on" ]; then
    /home/admin/config.scripts/internet.hiddenservice.sh btcpay 80 23002 443 23003
  fi
  if [ "${ElectRS}" = "on" ]; then
    /home/admin/config.scripts/internet.hiddenservice.sh electrs 50002 50002 50001 50001
  fi
  if [ "${LNBits}" = "on" ]; then
    /home/admin/config.scripts/internet.hiddenservice.sh lnbits 80 5002 443 5003
  fi
  if [ "${thunderhub}" = "on" ]; then
    /home/admin/config.scripts/internet.hiddenservice.sh thunderhub 80 3012 443 3013
  fi
  if [ "${specter}" = "on" ]; then
    # specter makes only sense to be served over https
    /home/admin/config.scripts/internet.hiddenservice.sh specter 443 25441
  fi
  if [ "${sphinxrelay}" = "on" ]; then
    /home/admin/config.scripts/internet.hiddenservice.sh sphinxrelay 80 3302 443 3303
    toraddress=$(sudo cat /mnt/hdd/tor/sphinxrelay/hostname 2>/dev/null)
    sudo -u sphinxrelay bash -c "echo '${toraddress}' > /home/sphinxrelay/sphinx-relay/dist/toraddress.txt"
  fi

    # get TOR address and store it readable for sphinxrelay user
    toraddress=$(sudo cat /mnt/hdd/tor/sphinxrelay/hostname 2>/dev/null)
    sudo -u sphinxrelay bash -c "echo '${toraddress}' > /home/sphinxrelay/sphinx-relay/dist/toraddress.txt"

  echo "Setup logrotate"
  # add logrotate config for modified Tor dir on ext. disk
  sudo tee /etc/logrotate.d/raspiblitz-tor >/dev/null <<EOF
/mnt/hdd/tor/*log {
        daily
        rotate 5
        compress
        delaycompress
        missingok
        notifempty
        create 0640 debian-tor debian-tor
        sharedscripts
        postrotate
                if invoke-rc.d tor status > /dev/null; then
                        invoke-rc.d tor reload > /dev/null
                fi
        endscript
}
EOF

  # make sure its the correct owner before last Tor restart
  sudo chmod -R 700 /mnt/hdd/tor
  sudo chown -R debian-tor:debian-tor /mnt/hdd/tor

  sudo systemctl restart tor@default

  echo "OK - Tor is now ON"
  echo "needs reboot to activate new setting"
  exit 0
fi

# switch off
if [ "$1" = "0" ] || [ "$1" = "off" ]; then
  echo "# switching Tor OFF"

  # setting value in raspi blitz config
  sudo sed -i "s/^runBehindTor=.*/runBehindTor=off/g" /mnt/hdd/raspiblitz.conf

  # *** CURL TOR PROXY ***
  # sudo rm /root/.curlrc
  # sudo rm /home/pi/.curlrc
  # sudo rm /home/admin/.curlrc

  # disable TOR service
  echo "# *** Disable Tor service ***"
  sudo systemctl disable tor@default
  echo ""

  # DEACTIVATE BITCOIN OVER TOR (function call)
  deactivateBitcoinOverTOR
  echo ""

  sudo /home/admin/config.scripts/internet.sh update-publicip
  
  if [ "${lightning}" == "lnd" ] || [ "${lnd}" == "on" ] || [ "${lnd}" == "1" ]; then
    echo "# *** Removing Tor from LND Mainnet ***"
    sudo sed -i '/^\[[Tt]or\].*/d' /mnt/hdd/lnd/lnd.conf
    sudo sed -i '/^tor\..*/d' /mnt/hdd/lnd/lnd.conf
    sudo systemctl restart lnd
  fi

  if [ "${tlnd}" == "on" ] || [ "${tlnd}" == "1" ]; then
    echo "# *** Removing Tor from LND Testnet ***"
    sudo sed -i '/^\[[Tt]or\].*/d' /mnt/hdd/lnd/tlnd.conf
    sudo sed -i '/^tor\..*/d' /mnt/hdd/lnd/tlnd.conf
    sudo systemctl restart tlnd
  fi

  if [ "${slnd}" == "on" ] || [ "${slnd}" == "1" ]; then
    echo "# *** Removing Tor from LND Signet ***"
    sudo sed -i '/^\[[Tt]or\].*/d' /mnt/hdd/lnd/slnd.conf
    sudo sed -i '/^tor\..*/d' /mnt/hdd/lnd/slnd.conf
    sudo systemctl restart slnd
  fi

  echo "# OK"
  echo ""

  echo "# *** Stop Tor service ***"
  sudo systemctl stop tor@default
  echo ""

  if [ "$2" == "clear" ]; then
      echo "# *** Deinstall Tor & Delete Data ***"
      sudo rm -r /mnt/hdd/tor 2>/dev/null
      sudo apt remove tor tor-arm -y
  fi

  echo "# needs reboot to activate new setting"
  exit 0
fi

# update
if [ "$1" = "update" ]; then
  # as in https://2019.www.torproject.org/docs/debian#source
  echo "# Install the dependencies"
  sudo apt update
  sudo apt install -y build-essential fakeroot devscripts
  sudo apt build-dep -y tor deb.torproject.org-keyring
  rm -rf /home/admin/download/debian-packages
  mkdir -p /home/admin/download/debian-packages
  cd /home/admin/download/debian-packages
  echo "# Building Tor from the source code ..."
  apt source tor
  cd tor-*
  debuild -rfakeroot -uc -us
  cd ..
  echo "# Stopping the tor.service before updating"
  sudo systemctl stop tor
  echo "# Update ..."
  sudo dpkg -i tor_*.deb
  echo "# Starting the tor.service "
  sudo systemctl start tor
  echo "# Installed $(tor --version)"
  if [ $(systemctl status lnd | grep -c "active (running)") -gt 0 ];then
    echo "# LND needs to restart"
    sudo systemctl restart lnd 
    sudo systemctl restart tlnd 2>/dev/null
    sudo systemctl restart slnd 2>/dev/null
    sleep 10
    lncli unlock
  fi
  exit 0
fi

echo "# FAIL - Unknown Parameter $1"
echo "# may needs reboot to run normal again"
exit 1
