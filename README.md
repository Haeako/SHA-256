# SHA-256 Hardware Implementation (Verilog)
Fully focus on SHA-256 implementation with **Carry-Select Adder (CSA)** to reduce the critical path and improve timing performance on FPGA.

This project is based on the open-source reference design from:  
👉 https://github.com/secworks/sha256.git

---

## ✨ Features
- Fully synthesizable SHA-256 implementation in Verilog  
- **Carry-Select Adder optimization** for improved FMax  
- Verified with functional simulation  
- Tested on Intel/Altera Cyclone-IV FPGA
---

## ⚙️ FPGA Synthesis Results

**Device:** Cyclone IV E – EP4CE6E22C6  
**Tool:** Quartus II 13.0 Web Edition  
**Corner:** Slow 85°C / 1200mV and Slow 0°C / 1200mV

### FMax Summary

| Model | Slow 85°C / 1200mV | Slow 0°C / 1200mV |
|-------|---------------------|--------------------|
| **FMax** | ~93.31 MHz | ~103 MHz |

---
📜 License
Original base code (secworks/sha256) under BSD license.
