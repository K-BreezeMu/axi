# AXI4 RAM 验证项目 (UVM)

## 项目状态
🟡 **WIP (Work In Progress)** - 本项目的 UVM 验证环境正在搭建中，目前已完成基础组件的框架搭建，正在完善 Refmodel 和 Scoreboard 的比对逻辑。

## DUT (Design Under Test) 简介
本项目的待测设计（DUT）是一个基于 AXI4 协议的片上 RAM（`axi_ram`）。该模块作为一个标准的 AXI4 从设备（Slave），接收来自主机（Master）的读写请求，并将其转换为内部 32-bit 宽度的存储阵列访问。

## 接口说明
DUT 采用标准的 AXI4 从机接口，主要参数配置如下：
*   **数据总线宽度 (`DATA_WIDTH`)**: 32 bit (4 Bytes)
*   **地址总线宽度 (`ADDR_WIDTH`)**: 16 bit (寻址空间 64 KB)
*   **ID 信号宽度 (`ID_WIDTH`)**: 8 bit
*   **字节掩码宽度 (`STRB_WIDTH`)**: 4 bit (`WSTRB`)
*   **复位信号**: `rst`，**高电平有效**（Active-High），复位时清空状态机但保留 RAM 内部数据。

### 信号通道
*   **AW (Write Address)**: 写地址通道。主机发起写事务时提供首地址、突发长度及大小。
*   **W (Write Data)**: 写数据通道。主机按拍发送 32-bit 数据及 `WSTRB` 掩码。
*   **B (Write Response)**: 写响应通道。DUT 接收完所有写数据后，返回响应。
*   **AR (Read Address)**: 读地址通道。主机发起读事务时提供读首地址。
*   **R (Read Data)**: 读数据通道。DUT 将一整块 32-bit 数据吐出，并用 `RLAST` 标记最后一拍。

## DUT 功能特性
1.  **突发类型 (Burst Type)**:
    *   **INCR (递增模式, `2'b01`)**: 最常用模式，地址按 `2^AxSIZE` 递增。
    *   **FIXED (固定模式, `2'b00`)**: 地址保持不变，持续写入同一地址。
    *   *(注：当前 RTL 不支持 WRAP 回绕模式)*
2.  **字节掩码控制 (WSTRB)**: 严格依赖 Master 给出的 `WSTRB` 决定 32-bit 总线上的哪几个字节（Lane）被真正写入内部 RAM，未选中字节保持不变。
3.  **内部寻址机制**: 内部存储阵列宽度为 32-bit。DUT 会将外部 16-bit 字节地址的末 2 位截断（`addr >> 2`）以查找内部 Word，并通过 `WSTRB` 匹配具体字节。
4.  **读操作全量输出**: 无论读请求的 `ARSIZE` 是多少，DUT 总是返回所在 32-bit 数据块的整体数据，由 Master 自行根据地址低位和 `ARSIZE` 过滤有效字节。
5.  **无 Outstanding 能力**: 当前 DUT 为极简设计，不支持乱序和并发操作（Outstanding），必须严格完成一次读写突发后，才能处理下一次请求。

## UVM 验证环境架构 (当前进度)
本项目使用 SystemVerilog + UVM 搭建验证环境，目前包含以下组件：
*   **`axi_transaction`**: 定义事务类型，包含激励随机字段与采集字段，通过 `op` 与 `is_write` 标识操作类型。
*   **`axi_driver`**: 负责解析 Sequence 下发的指令，严格按 AXI 协议时序驱动总线。目前支持 `reset`、`fixed_wr/rd`、`incr_wr/rd`。
*   **`axi_monitor`**: 挂载在总线上，利用 `fork...join` 并发监控 AW/W/B 与 AR/R 通道，将捕捉到的物理动作组装为完整的 Transaction，推送给 Scoreboard。
*   **`axi_refmodel`**: 理想行为模型（基于关联数组），根据写事务的 `WSTRB` 更新字节字典，在读操作时吐出整块对齐的 32-bit 期望数据。
*   **`axi_scoreboard`** *(搭建中)*: 接收 Monitor 的数据，调用 Refmodel 进行 Mask 掩码比对。

---
*Created for AXI4 RAM UVM Verification.*
- `cp_backpressure`：bready/rready 延迟 0 / 1 / 2-4 / 8+
- `cp_parallel`：读写并行 / 串行

---

## 10. 使用建议

- 参数建议：`DATA_WIDTH=32, ADDR_WIDTH=16, ID_WIDTH=4, PIPELINE_OUTPUT=0`
- `rst` 是高有效，别按低有效接，接反了仿真前几十拍全是 X
- `mem` 有 `initial` 清零，仿真可重复；但上板不保证，测试向量不要依赖初值
