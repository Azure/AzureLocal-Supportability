# 📘 Technical Docs and TSGs for Azure Local Networking & SDN

This folder contains references, deep dives, troubleshooting guides, and how-to documentation focused on Azure Local networking scenarios — including TOR Configurations, Arc Gateway & Outbound Connectivity, SDN, and more.

---

## 📂 Folder Structure

The repo is organized by **major topic areas**, with each folder containing related technical content:

| Folder                             | Description                                                          |
|------------------------------------|----------------------------------------------------------------------|
| `ArcGateway-OutboundConnectivity/` | Outbound traffic flow and connectivity through Arc Gateway.          |
| `HostNetworking/`                  | VM network adapters, VLANs, NIC teaming, and host-level traffic flow.|
| `Top-Of-Rack-Switch/`              | TOR switch configurations and best practices.                        |
| `SDN-Enabled-by-ARC/`              | SDN scenarios enabled through ARC.                                   |
| `SDN-Express/`                     | SDN scenarios enabled through SDN Express and WAC.                   |

---

## 📄 File Naming Conventions

To keep things organized and consistent, use the following naming schema for new files:

```
<type>-<topic>-<specifics>.md
```

### 🔧 `<type>` values:
| Type           | Use for...                                   |
|----------------|----------------------------------------------|
| `DeepDive`     | Detailed technical explanations              |
| `HowTo`        | Step-by-step deployment or config guides     |
| `Troubleshoot` | Troubleshooting known issues                 |
| `Reference`    | Reference configurations and resources       |

### Example `<topic>` values:
| Topic                         | Use for...                                   |
|-------------------------------|----------------------------------------------|
| `ArcGateway`                  | Detailed technical explanations              |
| `OutboundConnectivity`        | Step-by-step deployment or config guides     |
| `SDNExpress`                  | Troubleshooting known issues                 |
| `HostNetworking`              | Reference configurations and resources       |
| `TOR`                         | Reference configurations and resources       |

### 🌐 Examples:
- `Reference-TOR-Disaggregated-Switched-Storage`
- `Troubleshoot-SDNExpress-PolicyConfigurationFailure-VirtualGateway-NetworkConnection`
- `howto-hostnetworking-pnic-mapping.md`

Use **kebab-case** (`-`) for readability and consistency (words are lowercase and separated by hyphens).

---

## ✅ Contribution Guidelines

We welcome internal contributions to improve this repo. To contribute:

1. Choose the correct folder based on the topic.
2. Use the filename schema above.
3. Add a short entry to the folder’s `README.md` describing your new file.
4. Keep content focused, concise, and technically accurate.

If in doubt, open a draft PR for early feedback.

---

## 📬 Feedback

Have questions or want to suggest improvements? Open an issue or contact the repo owners.
