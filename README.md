# 📊 Speedtest Saint Petersburg

A comprehensive network speed testing tool specifically optimized for servers and users in Saint Petersburg, Russia. This script tests your connection against multiple local ISPs and provides detailed performance metrics.

## ✨ Features

- 🚀 Test connection speeds against major Saint Petersburg ISPs
- 📊 Detailed metrics including download/upload speeds and latency
- 🔍 Automatic server selection or manual server testing by ID
- 🛠️ Debug mode for troubleshooting
- 📝 Logging to file for later analysis
- 🎨 Color-coded output for better readability
- 🖥️ System information display
- 📈 I/O performance testing

## 🚀 Quick Start

### Prerequisites
- Linux/Unix-based system
- Bash shell
- `wget` or `curl`
- Internet connection

### Installation & Usage

#### As Regular User (recommended)
```bash
wget -qO- https://raw.githubusercontent.com/aleksandr-miheichev/speedtest-Saint-Petersburg/main/sbp_speedtest.sh | bash
```

#### As Root
```bash
wget -qO- https://raw.githubusercontent.com/aleksandr-miheichev/speedtest-Saint-Petersburg/main/sbp_speedtest.sh | sudo bash
```

## 🐛 Debug Mode

To run the script in debug mode (shows detailed execution information):

#### Regular User:
```bash
wget -qO- https://raw.githubusercontent.com/aleksandr-miheichev/speedtest-Saint-Petersburg/main/sbp_speedtest.sh | env DEBUG=1 bash
```

#### As Root:
```bash
wget -qO- https://raw.githubusercontent.com/aleksandr-miheichev/speedtest-Saint-Petersburg/main/sbp_speedtest.sh | env DEBUG=1 sudo bash
```

## 🎯 Test Specific Server

To test against a specific server using its ID:
```bash
speedtest --server-id=SERVER_ID
```

Example (to test RETN Saint Petersburg server):
```bash
speedtest --server-id=18570
```

## 📋 Supported Servers

| Server ID | Provider |
|-----------|---------------------------------|
| 18570     | RETN Saint Petersburg |
| 31126     | Nevalink Ltd. Saint Petersburg |
| 16125     | Selectel Saint Petersburg |
| 21014     | P.A.K.T. LLC Saint Petersburg |
| 4247      | MTS Saint Petersburg |
| 6051      | t2 Russia Saint Petersburg |
| 17039     | MegaFon Saint Petersburg |

## 📂 Files and Locations

- **Logs**: `~/.cache/speedtest-spb/speedtest.log`
- **Temporary Files**: Stored in system temp directory and automatically cleaned up

## 🛠️ Development

### Dependencies
- `wget` or `curl`
- `awk`
- `grep`
- `tr`

### Building
This is a bash script - no building is required. Simply make it executable:
```bash
chmod +x sbp_speedtest.sh
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📜 License

This project is open source and available under the [MIT License](LICENSE).

## 📞 Support

For support, please [open an issue](https://github.com/aleksandr-miheichev/speedtest-Saint-Petersburg/issues) on GitHub.

## 📊 Example Output

```
Node Name                      Download Speed    Upload Speed      Ping       
RETN Saint Petersburg          245.67 Mbps       198.45 Mbps       5.67 ms    
Nevalink Ltd. Saint Petersburg 198.76 Mbps       154.32 Mbps       7.89 ms    
Selectel Saint Petersburg      287.45 Mbps       201.56 Mbps       6.23 ms    
```

---

<div style="text-align: center; margin-top: 2em;">
  <p>Made with ❤️ for Saint Petersburg</p>
</div>
