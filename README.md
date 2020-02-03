HPE iLO 4 and iLO 5 mass upgrade script (Located in iLO-Firmware)
- Scans for out-of-date iLO's in specified IP range or from file. Creates a csv file for all scanned iLO devices.
- Upgrades all out-of-date iLO devices.
- Verifies upgrade by rescanning upgraded iLO devices. Creates a csv file for failed upgrades.
- Lists any devices that encounter an error during data collection.


iLO 4 2.72 download (Released Dec 20, 2019): https://support.hpe.com/hpsc/swd/public/detail?swItemId=MTX_73e5d39002d64f1ba55f91c90a

iLO 5 2.12 download (Released Jan 23, 2020): https://support.hpe.com/hpsc/swd/public/detail?swItemId=MTX_3fa9c00c8cb64f19ab248a265b


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
