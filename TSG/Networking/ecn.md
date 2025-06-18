# ECN

An example of **ECN packet codes**

| ECN Fields | Description               | Codepoints |
| ---------- | ------------------------- | ---------- |
| 0x00       | Non ENC-Capable Transport | Not-ECT    |
| 0x10       | ECN-Capable Transport     | ECT(0)     |
| 0x01       | ECN-Capable Transport     | ECT(1)     |
| 0x11       | Congestion Encountered    | CE         |

**Packet Capture showing ECN fields**
![packet capture showing ECN values](./images/ECN.png)
> [!Note]
> ETC(0) and ETC(1) are equilvant.
