# AXI4 RAM UVM Verification Project

> **Status: 🟡 WIP (Work In Progress) / 状态：🟡 开发中**  
> This project is currently under active development. The UVM environment skeleton and core components (Driver, Monitor, Refmodel) are implemented, while the Scoreboard and coverage collection are being refined.
> 本项目正在开发中。UVM 环境框架及核心组件（Driver、Monitor、Refmodel）已搭建，Scoreboard 与覆盖率收集正在完善中。

---

<details open>
<summary><b>🇬🇧 English Version</b></summary>

## 📌 DUT Overview

The Design Under Test (DUT) is an AXI4-compliant Block RAM (`axi_ram`). It acts as a standard AXI4 Slave device, receiving read/write requests from the master and translating them into internal 32-bit wide memory accesses.

### Parameter Configuration
The DUT is instantiated with the following key parameters:

| Parameter | Value | Description |
| :--- | :--- | :--- |
| `DATA_WIDTH` | 32 | Data bus width (4 Bytes) |
| `ADDR_WIDTH` | 16 | Address bus width (64 KB address space) |
| `ID_WIDTH` | 8 | Width of the AXI ID signals |
| `STRB_WIDTH` | 4 | Width of Write Strobe (`WSTRB`) |
| Reset Logic | `rst` | **Active-High** (0 for normal operation, 1 for reset). Note: Internal memory is *not* cleared upon reset. |

## 🔌 Interface & Channels

The DUT features a full standard AXI4 Slave interface with 5 independent channels:

- **AW (Write Address)**: Master provides the starting address, burst length (`AWLEN`), and burst size (`AWSIZE`).
- **W (Write Data)**: Master drives 32-bit `WDATA` along with `WSTRB` to indicate valid byte lanes.
- **B (Write Response)**: DUT returns `BRESP` after all write data is received.
- **AR (Read Address)**: Master provides the read starting address and burst configurations.
- **R (Read Data)**: DUT returns a full 32-bit data block, with `RLAST` marking the end of a burst.

## ⚙️ DUT Functional Features

1. **Burst Types**:
   - **INCR (Increment, `2'b01`)**: Addresses increment by `2^AxSIZE` per beat.
   - **FIXED (Fixed, `2'b00`)**: Address remains constant, overwriting the same memory location.
   - *(Note: The RTL does not support WRAP burst mode).*
2. **Byte Masking (`WSTRB`)**: The DUT strictly relies on the `WSTRB` signal to determine which byte lanes are written. Bytes with `WSTRB[n] == 0` remain unchanged.
3. **Internal Addressing**: The internal RAM array is 32-bit wide. The DUT truncates the lower 2 bits of the 16-bit byte address (`addr >> 2`) to locate the internal word, and uses `WSTRB` to resolve the exact byte.
4. **Read Data Output**: Regardless of the requested `ARSIZE`, the DUT always outputs the entire 32-bit data block from the targeted internal word. The master is responsible for filtering the valid bytes based on address alignment.
5. **No Outstanding Support**: As a simplified design, the DUT processes transactions serially. It does not support multiple outstanding transactions or out-of-order execution.

## 🏗️ UVM Environment Architecture (Current Progress)

The verification environment is built using SystemVerilog and UVM. The current structure includes:

- **`axi_transaction`**: Defines the transaction fields, using `op` and `is_write` to distinguish between write and read operations.
- **`axi_driver`**: Drives the AXI signals according to the protocol. Supports `reset`, `fixed_wr/rd`, and `incr_wr/rd` sequences.
- **`axi_monitor`**: Utilizes `fork...join` to concurrently monitor AW/W/B and AR/R channels, assembling physical bus activities into complete transactions.
- **`axi_refmodel`**: An ideal behavior model based on an associative array. Updates memory bytes based on `WSTRB` during writes and outputs the fully assembled 32-bit block during reads.
- **`axi_scoreboard`** *(In Progress)*: Receives transactions from the Monitor, fetches expected data from the Refmodel, and performs byte-level mask comparisons for reads.

</details>

---

<details open>
<summary><b>🇨🇳 中文版 (Chinese Version)</b></summary>

## 📌 DUT (待测设计) 概述

待测设计（DUT）是一个符合 AXI4 协议的片内 RAM（`axi_ram`）。它作为一个标准的 AXI4 从设备（Slave），接收来自主机的读写请求，并将其转换为内部 32-bit 宽度的存储阵列访问。

### 参数配置
DUT 例化时使用的主要参数如下：

| 参数名 | 值 | 说明 |
| :--- | :--- | :--- |
| `DATA_WIDTH` | 32 | 数据总线宽度 (4 Bytes) |
| `ADDR_WIDTH` | 16 | 地址总线宽度 (64 KB 寻址空间) |
| `ID_WIDTH` | 8 | AXI ID 信号宽度 |
| `STRB_WIDTH` | 4 | 写掩码 (`WSTRB`) 宽度 |
| 复位逻辑 | `rst` | **高电平有效**（0为正常工作，1为复位）。注意：复位不清空内部 RAM 数据。 |

## 🔌 接口与通道

DUT 拥有完整的标准 AXI4 从机接口，包含 5 个独立通道：

- **AW (写地址)**：主机提供写起始地址、突发长度（`AWLEN`）和突发大小（`AWSIZE`）。
- **W (写数据)**：主机发送 32-bit 数据（`WDATA`），并通过 `WSTRB` 指示哪些字节车道有效。
- **B (写响应)**：DUT 接收完所有写数据后，返回响应（`BRESP`）。
- **AR (读地址)**：主机提供读起始地址及突发配置。
- **R (读数据)**：DUT 吐出完整的 32-bit 数据块，通过 `RLAST` 标记突发结束。

## ⚙️ DUT 功能特性

1. **突发类型 (Burst Types)**：
   - **INCR (递增模式, `2'b01`)**：地址按 `2^AxSIZE` 递增。
   - **FIXED (固定模式, `2'b00`)**：地址保持不变，持续覆盖同一内存位置。
   - *（注：该 RTL 不支持 WRAP 回绕模式）*
2. **字节掩码 (`WSTRB`)**：DUT 严格依赖 `WSTRB` 信号决定实际写入的字节车道。`WSTRB[n] == 0` 的字节将保持不变。
3. **内部寻址机制**：内部 RAM 阵列为 32-bit 宽。DUT 会截断外部 16 位字节地址的低 2 位（`addr >> 2`）以定位内部字（Word），并通过 `WSTRB` 解析具体字节。
4. **读数据输出**：无论请求的 `ARSIZE` 是多少，DUT 总是输出目标内部字的完整 32-bit 数据块，由主机自行根据地址对齐情况过滤有效字节。
5. **无 Outstanding (未完成事务) 能力**：作为简化设计，DUT 串行处理事务，不支持多笔并发或乱序返回。

## 🏗️ UVM 验证环境架构 (当前进度)

验证环境基于 SystemVerilog 和 UVM 搭建，当前结构包含：

- **`axi_transaction`**：定义事务字段，通过 `op` 和 `is_write` 区分读写操作。
- **`axi_driver`**：按协议驱动 AXI 信号。支持 `reset`、`fixed_wr/rd`、`incr_wr/rd` 激励。
- **`axi_monitor`**：利用 `fork...join` 并发监控 AW/W/B 与 AR/R 通道，将物理总线活动组装成完整的事务。
- **`axi_refmodel`**：基于关联数组的理想行为模型。写操作时根据 `WSTRB` 更新内存字节；读操作时输出拼装好的完整 32-bit 数据块。
- **`axi_scoreboard`** *(开发中)*：接收 Monitor 的事务，从 Refmodel 获取期望数据，并对读操作进行字节级掩码比对。

</details>

---
#11.12日
# AXI4 RAM UVM Verification Project - Daily Progress

## 📅 今日战果：核心组件搭建完毕

成功搭建了完整的 AXI4 RAM UVM 验证环境骨架，包含以下核心文件：

- [x] **`axi_transaction`**：统一定义读写事务，新增 `is_write` 标志位。
- [x] **`axi_driver`**：严格按 AXI 时序驱动，支持 `reset`、`FIXED`、`INCR` 模式。
- [x] **`axi_monitor`**：使用 `fork...join` 并发监控读写通道，完整拼装总线事务。
- [x] **`axi_refmodel`**：基于关联数组的字节级理想模型，按 `WSTRB` 掩码精准更新。
- [x] **`axi_scoreboard`**：实现 **Mask 掩码比对** 逻辑，支持统计 `pass/fail`。
- [x] **`axi_agent` & `axi_env`**：完成标准 UVM 树形分层与 TLM 端口连接。

---

## 🔧 关键 Bug 修复记录

在编码过程中排查并解决了以下致命问题：

1. **时序竞争与死锁**：废弃 `wait()` 电平敏感等待，全面替换为严谨的 `do @(posedge clk); while(!(valid && ready))` 握手判断。
2. **地址截断灾难**：明确 Refmodel 中**先计算完整地址（`addr + i*size`），再进行 4 字节对齐（`& ~3`）**的规则，防止 INCR 模式下数据错位。
3. **句柄覆盖冲突**：将 Monitor 中的 `create("tr")` 移入 `forever` 循环内，确保每次 TLM 写入的数据安全独立。

---

## ✨ 核心亮点

- **深度理解 AXI 非对称性**：由于读通道无 `RSTRB`，Refmodel 吐出完整的 32-bit 块，Scoreboard 利用 `start_lane = addr % 4` 和字节切片 `[lane*8 +: 8]` 实现了**精准的窄传输比对**，完美过滤无效车道数据。
- **完备的双模式支持**：Refmodel 与 Scoreboard 均完美兼容 `FIXED`（地址不变，重复覆盖）与 `INCR`（地址按 `2^AxSIZE` 递增）模式。
- **工业级监控架构**：读写通道独立并行监控，互不阻塞，保障采集完整性。

---

## 🚀 Next Steps (下一步计划)

- [ ] **完善 `axi_transaction`**：补齐随机化约束，确保 `wdata.size()` 和 `wstrb.size()` 与 `awlen` 匹配，并加入合理的地址对齐约束。
- [ ] **搭建 `axi_subscriber`**：完成覆盖率收集器开发，对 `awsize`、`arsize`、`axburst` 以及 `wstrb` 的取值分布与交叉组合进行采样。
*Created for AXI4 RAM UVM Verification.*
