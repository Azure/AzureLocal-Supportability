# Explicit Congestion Notification

Explicit Congestion Notification (ECN) is a network congestion management mechanism that enables switches and routers to signal congestion without dropping packets. In Azure Local QoS implementations, ECN is specifically configured for storage (RDMA) traffic to maintain lossless transport while providing congestion feedback to endpoints.

## How ECN Works in Azure Local QoS

When implemented with WRED (Weighted Random Early Detection) in the QoS policy, ECN allows switches to mark packets instead of dropping them when queue thresholds are reached. For storage traffic (CoS 3), this is critical because RDMA requires lossless transport. The switch marks packets with congestion information, allowing the sending host to reduce its transmission rate and prevent further congestion, all while maintaining the lossless nature required for storage workloads.

This mechanism is particularly important in Azure Local environments where storage traffic must be protected from packet loss while still providing congestion control. The ECN marking occurs in the IP header's DSCP field using specific codepoints that communicate congestion status between network devices and endpoints.

An example of **ECN packet codes**

| ECN Fields | Description               | Codepoints |
| ---------- | ------------------------- | ---------- |
| 0x00       | Non ECN-Capable Transport | Not-ECT    |
| 0x10       | ECN-Capable Transport     | ECT(0)     |
| 0x01       | ECN-Capable Transport     | ECT(1)     |
| 0x11       | Congestion Encountered    | CE         |

> [!Note]
> ECT(0) and ECT(1) are equivalent and indicate that the transport protocol supports ECN.

**Packet Capture showing ECN fields**
![packet capture showing ECN values](./images/ECN.png)

## Reference

- [Cisco WRED-Explicit Congestion Notification][CiscoWredECN]
- [RFC 3168 - The Addition of Explicit Congestion Notification (ECN) to IP][rfc3168]

[CiscoWredECN]: https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_conavd/configuration/15-mt/qos-conavd-15-mt-book/qos-conavd-wred-ecn.html "WRED drops packets, based on the average queue length exceeding a specific threshold value, to indicate congestion. ECN is an extension to WRED in that ECN marks packets instead of dropping them when the average queue length exceeds a specific threshold value. When configured with the WRED -- Explicit Congestion Notification feature, routers and end hosts would use this marking as a signal that the network is congested and slow down sending packets."
[rfc3168]: https://www.rfc-editor.org/rfc/rfc3168 "We begin by describing TCP's use of packet drops as an indication of congestion.  Next we explain that with the addition of active queue management (e.g., RED) to the Internet infrastructure, where routers detect congestion before the queue overflows, routers are no longer limited to packet drops as an indication of congestion.  Routers can instead set the Congestion Experienced (CE) codepoint in the IP header of packets from ECN-capable transports.  We describe when the CE codepoint is to be set in routers, and describe modifications needed to TCP to make it ECN-capable.  Modifications to other transport protocols (e.g., unreliable unicast or multicast, reliable multicast, other reliable unicast transport protocols) could be considered as those protocols are developed and advance through the standards process.  We also describe in this document the issues involving the use of ECN within IP tunnels, and within IPsec tunnels in particular."
