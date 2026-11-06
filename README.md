# axi_ram 规格书（DUT: axi_study/dut/axi_ram.v）
来源：alexforencich/verilog-axi
性质：单端口 AXI4 从端 RAM，带独立读写状态机，可读写并行

---

## 1. 概述

`axi_ram` 是一个支持 AXI4 从端接口的片上 RAM 模型。
外部通过五条 AXI 通道访问内部存储阵列，内部实现为：
- 一个写状态机（3 态）：IDLE / BURST / RESP
- 一个读状态机（2 态）：IDLE / BURST
- 一块双访问口存储 `mem`，读写使用同一时钟

**同一时刻只允许一笔写事务和一笔读事务在进行，读写之间可以并行。**
本模块**不支持** outstanding（多笔未完成事务）。

---

## 2. 参数与推导

| 参数 | 默认值 | 说明 |
|---|---|---|
| `DATA_WIDTH` | 32 | 数据位宽（bit） |
| `ADDR_WIDTH` | 16 | 地址位宽（byte 地址） |
| `STRB_WIDTH` | DATA_WIDTH/8 = 4 | 写选通位宽（字节数） |
| `ID_WIDTH` | 8 | ID 位宽 |
| `PIPELINE_OUTPUT` | 0 | 1 = 读通道输出加一级流水寄存器 |

内部推导：

| 常量 | 表达式 | 默认值 | 含义 |
|---|---|---|---|
| `VALID_ADDR_WIDTH` | ADDR_WIDTH − clog2(STRB_WIDTH) | 14 | 存储器字索引位宽 |
| `WORD_WIDTH` | STRB_WIDTH | 4 | 一个字的字节数 |
| `WORD_SIZE` | DATA_WIDTH/WORD_WIDTH | 8 | 一个字节的位宽 |

**存储容量** = 2^14 × 4 B = **64 KB**（16384 个 32 位字）

参数合法性在 `initial` 块中检查，不合法直接 `$error` + `$finish`：
- `WORD_SIZE × STRB_WIDTH` 必须等于 `DATA_WIDTH`
- `STRB_WIDTH` 必须是 2 的幂

---

## 3. 接口信号

### 时钟与复位
| 信号 | 方向 | 位宽 | 说明 |
|---|---|---|---|
| `clk` | in | 1 | 时钟 |
| `rst` | in | 1 | **高有效同步复位** |

### 写地址通道 AW
| 信号 | 方向 | 位宽 | 说明 |
|---|---|---|---|
| `s_axi_awid` | in | ID_WIDTH | 写入事务 ID，最终回在 BID 上 |
| `s_axi_awaddr` | in | ADDR_WIDTH | 起始字节地址 |
| `s_axi_awlen` | in | 8 | 拍数 − 1 |
| `s_axi_awsize` | in | 3 | 每拍字节数，**>2 会被截断为 2** |
| `s_axi_awburst` | in | 2 | 00=FIXED，其他值一律按递增处理 |
| `s_axi_awlock` | in | 1 | **未使用** |
| `s_axi_awcache` | in | 4 | **未使用** |
| `s_axi_awprot` | in | 3 | **未使用** |
| `s_axi_awvalid` | in | 1 | 地址有效 |
| `s_axi_awready` | out | 1 | 仅在写 IDLE 时拉高 |

### 写数据通道 W
| 信号 | 方向 | 位宽 | 说明 |
|---|---|---|---|
| `s_axi_wdata` | in | DATA_WIDTH | 写数据 |
| `s_axi_wstrb` | in | STRB_WIDTH | 字节选通，逐字节控制写入 |
| `s_axi_wlast` | in | 1 | **DUT 不检查**，结束由内部计数决定 |
| `s_axi_wvalid` | in | 1 | 数据有效 |
| `s_axi_wready` | out | 1 | BURST 态拉高 |

### 写响应通道 B
| 信号 | 方向 | 位宽 | 说明 |
|---|---|---|---|
| `s_axi_bid` | out | ID_WIDTH | 等于锁存的 AWID |
| `s_axi_bresp` | out | 2 | **恒为 2'b00（OKAY）** |
| `s_axi_bvalid` | out | 1 | 一拍有效，直到 bready 握手 |
| `s_axi_bready` | in | 1 | 主机接收 |

### 读地址通道 AR / 读数据通道 R
| 信号 | 方向 | 位宽 | 说明 |
|---|---|---|---|
| `s_axi_arid` | in | ID_WIDTH | 读事务 ID |
| `s_axi_araddr` | in | ADDR_WIDTH | 起始字节地址 |
| `s_axi_arlen` | in | 8 | 拍数 − 1 |
| `s_axi_arsize` | in | 3 | **>2 会被截断为 2** |
| `s_axi_arburst` | in | 2 | 同上，非 00 一律递增 |
| `s_axi_arlock/cache/prot` | in | — | **未使用** |
| `s_axi_arready` | out | 1 | 仅在读 IDLE 时拉高 |
| `s_axi_rid` | out | ID_WIDTH | 等于锁存的 ARID |
| `s_axi_rdata` | out | DATA_WIDTH | 读数据（整个字，见 §5.3） |
| `s_axi_rresp` | out | 2 | **恒为 2'b00（OKAY）** |
| `s_axi_rlast` | out | 1 | 最后一拍有效 |
| `s_axi_rvalid` | out | 1 | 读数据有效 |
| `s_axi_rready` | in | 1 | 主机接收 |

---

## 4. 写通路行为

### 4.1 状态机

```
        awvalid & awready
IDLE ───────────────────────► BURST ──(count==0 且 bready||!bvalid)──► IDLE
  ▲   awready=1               wready=1 │
  │                                    └──(count==0 且 bvalid 且 !bready)──► RESP
  └──────────────────────────────────────────────────────────────── RESP 等 bready
```

### 4.2 逐拍语义

| 阶段 | 行为 |
|---|---|
| IDLE | `awready` 拉高。`awvalid && awready` 那一拍锁存 AWID/AWADDR/AWLEN/AWSIZE/AWBURST，同时 `awready` 拉低、`wready` 拉高，进入 BURST |
| BURST | 每拍 `wvalid && wready`：按 `wstrb` 逐字节写入 `mem[addr>>shift]`；`count--`；若 burst ≠ 00 则地址 += (1<<size) |
| 结束 | `count` 减到 0 的那一拍，若 `bready` 为 1（或当前 bvalid 为 0），直接发 B 并回 IDLE；否则进 RESP 挂着 bvalid 等 bready |
| RESP | 等 `bready`，握手后回 IDLE |

### 4.3 地址映射

```verilog
word_index = awaddr >> (ADDR_WIDTH - VALID_ADDR_WIDTH)   // 默认 >>2，即除以 4
```

- **地址低 2 位被直接丢弃**，不做非对齐移位补偿
- 非对齐 start address 需要主机自己把数据放到正确的 byte lane 上（AXI 标准做法）
- 地址超过 64 KB 时会因索引位宽截断而**绕回低地址**，不报错

### 4.4 WSTRB 语义

```verilog
if (mem_wr_en & wstrb[i])
    mem[word][WORD_SIZE*i +: WORD_SIZE] <= wdata[WORD_SIZE*i +: WORD_SIZE];
```
逐字节选通，未选通的字节保持原值。`wstrb = 0` 时该拍不写任何字节（但仍然消耗一拍计数）。

### 4.5 响应

- `bid` = 锁存的 `awid` ✔ 正确
- `bresp` 恒 `2'b00`，**无错误响应能力**

---

## 5. 读通路行为

### 5.1 状态机

```
        arvalid & arready
IDLE ────────────────────► BURST ──(count==0)──► IDLE
  ▲  arready=1             每拍取数、计数递减
  └──────────────────────────────┘
```

### 5.2 时序要点

- `arready` 只在 IDLE 拉高，**收到 AR 后立刻拉低**，直到本轮 burst 完成才恢复 → 无 outstanding
- 进入 BURST 后，**不等待 arvalid 之外的任何握手**，靠 `rready || !rvalid` 自行推进
- 每拍从 `mem[addr>>shift]` 取数，打到 `rdata` 寄存器，因此**首拍有 1 个时钟的延迟**
- `rlast` 在 `count == 0` 的那一拍置起
- 最后一拍 `count` 归零后立刻恢复 `arready`，回 IDLE

### 5.3 窄传输的数据放置

读出的永远是**整个 word**，不做 lane 移位。按 AXI 规范，窄读时未使用的 byte lane 上的值不参与判定，因此功能上可用，但 scoreboard 比较时必须**只比较有效字节**。

### 5.4 PIPELINE_OUTPUT

`PIPELINE_OUTPUT=1` 时，读数据经 `rid/rdata/rlast/rvalid` 再打一级寄存器输出，等效多 1 拍延迟。
写通路与 B 通道不受此参数影响。

---

## 6. 能力矩阵（重要）

| 特性 | 支持 | 说明 |
|---|---|---|
| FIXED burst | ✅ | `awburst == 2'b00` 时地址不递增 |
| INCR burst | ✅ | 地址 += (1<<size) |
| **WRAP burst** | ❌ | 任何非 00 的 burst 都按递增处理，**WRAP 被当成 INCR** |
| 窄传输（size < 2） | ⚠️ | 能用，但地址低位直接丢弃，全靠主机端 lane 对齐 |
| size = 3（8 字节/拍） | ❌ | 被截断为 2，主从地址推进不一致，数据会错位 |
| outstanding | ❌ | awready 仅 IDLE 拉高；arready 完成本轮才恢复 |
| 错误响应 SLVERR/DECERR | ❌ | bresp/rresp 硬接 00 |
| 4KB 边界检查 | ❌ | 不检查，起始地址靠近边界时可跨过 |
| 地址越界保护 | ❌ | 索引截断后静默回绕 |
| 复位清存储 | ❌ | `rst` 只清状态与握手寄存器，`mem` 由 `initial` 块清零（仅仿真有效） |
| 读写并行 | ✅ | 两套独立状态机，共用时钟 |
| 写数据交织 | ❌ | AXI4 本身不允许，仅记录 |

---

## 7. 复位行为

```verilog
if (rst) begin
    write_state_reg   <= IDLE;
    s_axi_awready_reg <= 0;
    s_axi_wready_reg  <= 0;
    s_axi_bvalid_reg  <= 0;
    read_state_reg    <= IDLE;
    s_axi_arready_reg <= 0;
    s_axi_rvalid_reg  <= 0;
end
```

- 同步、高有效
- **不复位** `mem`、`bid/rid`、`rdata`
- 复位释放后需要至少一个周期才会重新拉高 `awready/arready`

---

## 8. 典型时序（INCR 4 拍写）

```
clk      _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
awvalid  __/‾‾‾\_____________________
awready  ‾‾\_______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
wvalid   ____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_______
wready   ____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_______
wlast    ____________/‾‾‾‾‾‾‾\_______
bvalid   ____________________/‾‾‾‾‾\___
```
（示意，非精确到周期）

---

## 9. 验证要点

### 9.1 必测项
1. 单拍写读（AWLEN=0）数据一致性
2. INCR 4/8/16 拍读写，地址步进正确
3. FIXED burst：地址不变，末拍数据生效
4. WSTRB 全 0 / 单字节 / 组合，未选通字节保持原值
5. 窄传输 size=0/1/2 的数据 lane 位置
6. 反压：`bready`、`rready` 随机延迟，检查 `bvalid/rvalid` 是否稳定
7. AW 与 W 到达顺序：AW 先到、同时到、W 先到
8. 读写并行：同时发起读写，检查互不干扰
9. 复位：传输中途复位，检查 rvalid/bvalid 拉低
10. 连续 back-to-back 事务

### 9.2 需要"定性"而非"找 bug"的项
- **WRAP burst**：预期现象是被当作 INCR。要写用例证明，然后判定为「规格不符 / 已知限制」
- **size=3**：预期现象是主从地址推进不一致，数据错位
- **地址越界**：预期是静默回绕，不报错
- **4KB 跨界**：预期不检查

这几条不叫 bug，叫「实现范围」。验证的价值在于把它们写成文档，而不是打叉。

### 9.3 断言清单
```systemverilog
// A1 复位期间无 bvalid/rvalid
// A2 VALID 拉高后到 READY 之前数据保持稳定
// A3 BID == 最后一个 AWID
// A4 RID == ARID 且整轮 burst 不变
// A5 RLAST 出现在第 ARLEN+1 拍
// A6 同一时刻 outstanding 写 ≤ 1（体现设计约束）
// A7 无 X 输出
```

### 9.4 覆盖率模型
- `cp_burst`：FIXED / INCR / WRAP（WRAP 用于证明不支持）
- `cp_len`：0 / 1 / 3 / 7 / 15 / 255
- `cp_size`：0 / 1 / 2 / 3
- `cp_addr_low`：起始地址低 2 位 0~3
- `cp_wstrb`：0 / 单字节 4 种 / 双字节 / 全 1
- `cp_backpressure`：bready/rready 延迟 0 / 1 / 2-4 / 8+
- `cp_parallel`：读写并行 / 串行

---

## 10. 使用建议

- 参数建议：`DATA_WIDTH=32, ADDR_WIDTH=16, ID_WIDTH=4, PIPELINE_OUTPUT=0`
- `rst` 是高有效，别按低有效接，接反了仿真前几十拍全是 X
- `mem` 有 `initial` 清零，仿真可重复；但上板不保证，测试向量不要依赖初值
