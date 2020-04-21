HPE iLO 4 and iLO 5 mass upgrade script (Located in iLO-Firmware)
- Scans for out-of-date iLO's in specified IP range or from file. Creates a csv file for all scanned iLO devices.
- Upgrades all out-of-date iLO devices.
- Verifies upgrade by rescanning upgraded iLO devices. Creates a csv file for failed upgrades.
- Lists any devices that encounter an error during data collection.


iLO 4 2.73 download (Released Feb 13, 2020): https://support.hpe.com/hpsc/swd/public/detail?swItemId=MTX_ba3437a6c8d843f39ab5cace06

iLO 5 2.14 download (Released Feb 13, 2020): https://support.hpe.com/hpsc/swd/public/detail?swItemId=MTX_a9cfde8ba427435488d972d68f


HPE ilO 4 Setting (Located in iLO-Settings)
- Allows you to set a number of attributes and settings in an iLO configuration

Settings that are changed:
- AlertMail
- Syslog
- iLO Admin User
- SNMP
- WINS Servers (IPv4)
- License Key
- Directory Group (for AD authentication)
- Directory Settings (for AD authentication)
- SNTP
- DNS Servers (IPv4)
