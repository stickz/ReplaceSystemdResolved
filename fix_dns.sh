export logfile="/dev/null"

#update and upgrade system
echo "Updating package lists" | tee $logfile
apt-get -qq update | tee -a $logfile

# Installing Aptitude
apt-get -qqy install aptitude >> $logfile 2>&1

echo "Upgrading packages" | tee -a $logfile
export DEBIAN_FRONTEND=noninteractive
aptitude -q=5 -y upgrade >> $logfile 2>&1
if ! [ $? = 0 ]; then
  echo "Problem upgrading packages. Run 'aptitude upgrade' successfully and rerun the script" && exit
fi

aptitude clean && aptitude autoclean >> $logfile 2>&1

setup_resolvconf_file() {
  # Remove the symlinked resolv.conf file
  rm /etc/resolv.conf >> $logfile 2>&1

  # Create new resolv.conf file. Add dnsmasq and cloudflare dns server
  bash -c 'echo nameserver 127.0.0.1 >> /etc/resolv.conf'
  bash -c 'echo nameserver 1.1.1.1 >> /etc/resolv.conf'

  # Make resolv.conf file immutable to prevent DNS issues
  chattr +i /etc/resolv.conf >> $logfile 2>&1
}

### INSTALL DNSMASQ ###
echo "Installing Dnsmasq"

# Disable the resolved service
systemctl disable systemd-resolved >> $logfile 2>&1
systemctl stop systemd-resolved >> $logfile 2>&1

# Remove immutablity on resolv.conf file (if present)
chattr -i /etc/resolv.conf >> $logfile 2>&1

# Run procress to setup resolvconf file
setup_resolvconf_file;

# Install dnsmasq from repository
aptitude -q=5 -y install dnsmasq >> $logfile 2>&1

### INSTALL resolvconf ###
echo "Installing resolvconf"

# Remove immutablity on resolv.conf file
chattr -i /etc/resolv.conf >> $logfile 2>&1

# Install resolvconf
aptitude -q=5 -y install resolvconf >> $logfile 2>&1

# Run procress to setup resolvconf file
setup_resolvconf_file;

###############################
### CONFIGURE DNSMASQ ###
###############################

# Update configuration varriables in /etc/dnsmasq.conf
sed -i "s/#port=5353/port=53/g" /etc/dnsmasq.conf
sed -i "s/#domain-needed/domain-needed/g" /etc/dnsmasq.conf
sed -i "s/#bogus-priv/bogus-priv/g" /etc/dnsmasq.conf
sed -i "s/#strict-order/strict-order/g" /etc/dnsmasq.conf
sed -i "s/#listen-address=/listen-address=127.0.0.1/g" /etc/dnsmasq.conf

# Restart dnsmasq service when completed
service dnsmasq restart >> $logfile 2>&1

echo "Script completed"