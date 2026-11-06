# AXI3 Slave 验证规格书 v0.1

被测对象：`wanderingsonder/AXI3-Slave-UVM-Verification` → `rtl/axi_slave.sv`
用途：作为验证练习的"需求基线"。第 4 章是判断对错的依据，第 6 章是干活清单，
第 10 章是线索（想看自己找就先别看）。

---

## 1. DUT 概述

| 项目 | 值 |
|---|---|
| 协议 | AXI3（AMBA） |
| 数据宽度 | 32 bit |
| 地址宽度 | 32 bit |
| ID 宽度 | 4 bit（AWID / WID / BID / ARID / RID） |
| 支持 burst | FIXED(2'b00) / INCR(2'b01) / WRAP(2'b10) |
| 最大 burst | AWLEN 4 bit，即 1~16 拍 |
| 支持 size | AWSIZE ≤ 3'b010（≤4 字节） |
| 存储 | `logic [7:0] memory [128]`，128 字节 = 32 个字 |
| 有效地址空间 | 0x00 ~ 0x7F（即 0~127） |
| 复位 | RTL 中为**异步低有效**（`posedge clk or negedge resetn`），README 写的是同步，见 Q-01 |
| 结构 | 写数据 FSM、写响应 FSM、读 FSM 三个并行状态机 |

存储是**字节数组**，这一点决定了参考模型必须按字节建模，不能按字。

---

## 2. 接口

| 通道 | 信号 | 方向 |
|---|---|---|
| 全局 | clk, resetn | in |
| AW | awid[3:0], awaddr[31:0], awlen[3:0], awsize[2:0], awburst[1:0], awvalid, awready | in / out |
| W | wid[3:0], wdata[31:0], wstrb[3:0], wlast, wvalid, wready | in / out |
| B | bid[3:0], bresp[1:0], bvalid, bready | out / in |
| AR | arid[3:0], araddr[31:0], arlen[3:0], arsize[2:0], arburst[1:0], arvalid, arready | in / out |
| R | rid[3:0], rdata[31:0], rresp[1:0], rlast, rvalid, rready | out / in |

响应编码：OKAY=2'b00，EXOKAY=2'b01，SLVERR=2'b10，DECERR=2'b11。
本 DUT 只应出现 OKAY 与 SLVERR。

---

## 3. 待确认项（Spec Question，写进验证报告）

- Q-01 复位是同步还是异步？RTL 与 README 不一致，按 RTL 验证，提 issue。
- Q-02 memory 无复位，上电内容为 X。是否要求读未写地址返回确定值？
- Q-03 AWSIZE>2 时是"不支持并报错"还是"不支持且行为未定义"？
- Q-04 越界地址的定义：addr > 127 还是 addr ≥ 128？（注意两者在本设计里是同一件事，但代码里用了 `>`，见线索）
- Q-05 不支持写交织（WID），是否明确只在单笔 outstanding 下工作？

---

## 4. 功能需求（判断对错的基线）

### 4.1 复位

- **R-01** resetn 为低时，awready/wready、bvalid/rvalid 均不得为高；三个 FSM 回到 idle。
- **R-02** 复位释放后一拍，DUT 可正常接受事务，且不残留复位前的 B/R。
- **R-03** burst 传输中途复位，DUT 不得死锁，复位后能重新开始。

### 4.2 写地址通道 AW

- **R-10** AWVALID 与 AWREADY 同时为高的那个时钟沿，AWID/AWADDR/AWLEN/AWSIZE/AWBURST 必须被锁存。
- **R-11** 锁存值必须在整笔 burst 期间保持不变（后续 AW 不得污染）。
- **R-12** 忙时（已接受 AW 但未回 B）AWREADY 应拉低，即同一时刻只处理一笔写。
- **R-13** AWREADY 不应依赖 WVALID（可依赖 AWVALID，但会造成吞吐损失，作为警告项）。

### 4.3 写数据通道 W

- **R-20** 一笔 N 拍的写，WVALID/WREADY 必须握手恰好 N 次。
- **R-21** 第 n 拍（n 从 0 起）落盘的地址：
  - FIXED：恒为 AWADDR
  - INCR：AWADDR + n × (1<<AWSIZE)
  - WRAP：在大小为 N×(1<<AWSIZE) 的对齐块内回绕
- **R-22** WSTRB 按字节生效：wstrb[i]=1 才写 memory[addr+i]，为 0 的字节保持原值。
- **R-23** 数据必须写在第 n 拍**握手成功那一刻**总线上的 wdata，不得出现"慢一拍采样"。
- **R-24** WLAST 必须落在第 N 拍（N = AWLEN+1）。早于或晚于都算错。
- **R-25** W 通道不得早于 AW 通道（无不带地址的写数据）。
- **R-26** WREADY 拉高后，若 WVALID 未到，应保持拉高；不得出现"只在 WVALID 为高的那拍才给 ready"的抖动（性能项，非功能错）。

### 4.4 写响应通道 B

- **R-30** 一笔写只产生一个 B，且必须晚于最后一个 W 拍握手。
- **R-31** BID 必须等于该笔写的 AWID。
- **R-32** BRESP：地址越界 → SLVERR(2'b10)，否则 OKAY。
- **R-33** BVALID 拉高后必须保持，直到 BREADY 为高。
- **R-34** B 与后续笔的 AW 不得串味（连续两笔写，B 顺序与 AW 顺序一致）。

### 4.5 读地址通道 AR

- **R-40** ARVALID & ARREADY 同拍时锁存 ARID/ARADDR/ARLEN/ARSIZE/ARBURST。
- **R-41** ARREADY 不得依赖 ARVALID。
- **R-42** 同一时刻只处理一笔读。

### 4.6 读数据通道 R

- **R-50** 一笔 N 拍读，RVALID/RREADY 握手恰好 N 次。
- **R-51** RLAST 落在第 N 拍。
- **R-52** RID 恒等于该笔的 ARID，且在整笔期间保持。
- **R-53** RRESP 逐拍有效：
  - OKAY：本拍地址落在 0x00~0x7F
  - SLVERR：本拍地址越界
- **R-54** 读数据为本拍地址起的 4 字节小端拼接：`{mem[a+3],mem[a+2],mem[a+1],mem[a]}`。
- **R-55** RVALID 拉高后保持，直到 RREADY 为高。
- **R-56** 写后读一致性：写进去什么，读出来就是什么（含 wstrb 部分写）。
- **R-57** 读不得访问 memory[128] 及以上的下标（越界访问属于未定义行为，但 TB 应能捕获）。

### 4.7 Burst 约束

- **R-60** INCR burst 不得跨 4KB 边界（AXI 强制）。
- **R-61** WRAP 只允许 2/4/8/16 拍（AWLEN ∈ {1,3,7,15}），且起始地址按 size 对齐。
- **R-62** AWLEN=0（单拍 burst）必须支持。
- **R-63** 三通道并行：写数据、写响应、读可以同时进行，互不阻塞。

---

## 5. 验证环境要求

1. **clocking block 必须做**，`default input #1step`。否则采样竞争，数据比对结论不可信。
2. **driver 必须严格遵守 VALID 保持规则**：valid 拉高后，直到 ready 才允许改数据。
   这是暴露"慢一拍采样"类 bug 的前提，driver 写松了会掩盖问题。
3. **monitor 每笔事务新建对象**，禁止复用句柄（否则 scoreboard 比的是同一块内存）。
4. **参考模型**：`logic [7:0] ref_mem[128]`，行为：
   - 写：按 wstrb 字节写
   - 读：按小端拼 4 字节
   - 越界：记 SLVERR，**不更新 ref_mem**
5. **scoreboard 三类检查**：
   - 数据比对（读回值 vs ref_mem）
   - 响应比对（RRESP/BRESP vs 期望）
   - 协议检查（独立于 DUT 的断言）
6. **时序检查点**（容易漏的）：
   - W 拍数与 AWLEN+1 是否一致
   - RLAST / WLAST 位置
   - B 是否在最后一个 W 拍之后
   - BID/RID 是否等于对应 AWID/ARID
   - valid 是否保持到 ready

---

## 6. 测试用例矩阵

| ID | 层次 | 激励 | 主要检查点 |
|---|---|---|---|
| TC-01 | 冒烟 | 复位 10 拍，不发事务 | R-01, R-02 |
| TC-02 | 功能 | 单拍写 + 单拍读，addr=0 | R-20, R-50, R-56 |
| TC-03 | 功能 | FIXED，AWLEN=7，8 拍 | R-21, R-24 |
| TC-04 | 功能 | INCR，AWLEN=7，addr=0x00 | R-21, R-23 |
| TC-05 | 功能 | INCR，AWLEN=15，16 拍 | R-60 |
| TC-06 | 功能 | WRAP，AWLEN=1（2 拍） | R-21, R-61 |
| TC-07 | 功能 | WRAP，AWLEN=3（4 拍），起始 addr 非对齐块首 | R-21, R-61 |
| TC-08 | 功能 | WRAP，AWLEN=7（8 拍） | R-21 |
| TC-09 | 功能 | WRAP，AWLEN=15（16 拍） | R-21 |
| TC-10 | 功能 | wstrb 16 种取值各一遍 | R-22 |
| TC-11 | 压力 | wvalid 随机插入空隙（1~5 拍） | R-20, R-26 |
| TC-12 | 压力 | rready 随机延迟 | R-50, R-55 |
| TC-13 | 边界 | 读 addr=0x7C，4 字节（正好到 0x7F） | R-53, R-54 |
| TC-14 | 错误 | 读 addr=0x80 | R-53 |
| TC-15 | 错误 | 写 addr=0x80 | R-32 |
| TC-16 | 错误 | INCR addr=0x78, AWLEN=7（跨出 0x7F） | R-32, R-53 |
| TC-17 | 错误 | AWSIZE=3'b011（8 字节） | Q-03 |
| TC-18 | 异常 | burst 中途拉低 resetn，再释放 | R-03 |
| TC-19 | 并发 | 写进行中同时发起读 | R-63 |
| TC-20 | 并发 | 写后立刻读同一地址（无间隔） | R-56 |
| TC-21 | 协议 | WID ≠ AWID | R-31（ID 归属） |
| TC-22 | 协议 | 先发 W 再发 AW（非法激励） | DUT 不得死锁 |
| TC-23 | 随机 | 1000 笔随机 burst 回归 | 全部 |
| TC-24 | 性能 | 背靠背 burst，AW 与 B 之间不留空拍 | R-12, R-30 |

抽查建议：先跑 TC-02/04/07 三个，能过再往下。TC-04 是最容易暴露问题的。

---

## 7. 覆盖率模型

**功能覆盖点**

- cp_awlen：0~15 全值
- cp_awsize：0/1/2（3 单独 bin，作为非法）
- cp_awburst：FIXED/INCR/WRAP
- cp_addr_low：awaddr[1:0] 四种对齐情况
- cp_addr_region：0x00~0x7F 内 / 越界
- cp_wstrb：16 种取值
- cp_awlen_at_boundary：AWLEN ∈ {0,1,3,7,15}
- cp_rresp：OKAY / SLVERR
- cp_bresp：OKAY / SLVERR

**交叉覆盖**

- awburst × awlen
- awburst × addr_low（WRAP 对齐要求）
- wstrb × awburst

**断言覆盖**：每个 SVA 至少触发一次失败路径的"近邻"场景。

---

## 8. 断言清单（SVA）

1. `awvalid` 拉高后，直到 `awready` 不得撤销、且地址类信号保持
2. `wvalid` 拉高后，直到 `wready` 数据与 wlast/wstrb 保持
3. `rvalid` 拉高后，直到 `rready` rdata/rresp/rlast/rid 保持
4. `bvalid` 拉高后，直到 `bready` bresp/bid 保持
5. `bvalid` 不得早于该笔最后一个 W 拍
6. `rlast` 必须出现在第 ARLEN+1 拍
7. `wlast` 必须出现在第 AWLEN+1 拍
8. `bid == awid`（对应笔）
9. `rid == arid`（对应笔）
10. `resetn` 低期间 `bvalid/rvalid` 恒为 0
11. INCR burst 地址区间不得跨 4KB
12. `awaddr`/`araddr` 越界时对应 `bresp`/`rresp` 必须为 SLVERR

---

## 9. 通过准则

- 全部 TC 无 UVM_ERROR / UVM_FATAL
- 功能覆盖率 ≥ 95%，交叉覆盖率 ≥ 90%
- 断言全部通过，且被证明"能抓到错"（做一次注入错误实验）
- 每次失败必须有波形定位，不能以"改了 TB 就过了"收尾

---

## 10. 可疑点线索（分级，自己做的话建议只看 L1）

### L1：区域提示
1. 写数据 FSM 的 `waddr_dec` 与 `wstart` 两个状态之间，数据是在哪一拍落进 memory 的？
2. `wready` 的赋值位置和条件。
3. 写响应 FSM 里 `bresp`、`bid` 的来源。
4. 读 FSM 里 `rresp` 的计算用了哪个地址、哪个比较符。
5. `rdata`/`rresp` 在哪些状态没有赋值。
6. `awready` 的成立条件。
7. 越界地址仍然会对 memory 做什么操作。
8. 读 FSM 里 `rdlen_count` 的两处比较。

### L2：现象提示
1. 8 拍写，实际落盘可能是 7 拍，且地址整体偏移一拍。
2. 给出第一拍时 ready 已高，但那一拍的数据没有被记录。
3. 写错误响应看起来和地址无关。
4. 错误响应出现在"下一拍地址"上，且边界值判断差一。
5. 两个输出信号在 idle 状态下是未驱动的（锁存行为）。
6. 忙时无法接收下一笔 AW。
7. 地址接近 0x7F 时会访问到数组边界之外。

### L3：定位提示（不到卡死别看）
- `waddr_dec` 中 `wready=1` 无条件，但该状态的握手数据没有写 memory；写入发生在下一状态的 `if(wvalid)` 分支里，用的是当时的 `wdata`。
- `wstart`/`wreadys` 的 `wready = 1` 写在 `if(wvalid)` 内部。
- `bresp = (awsize > 3'b010) ? 2'b10 : 2'b00`；`bid = wid`。
- `rresp = (rdnextaddr_next > 128) ? 2'b10 : 2'b00`，用的是下一拍地址，比较符是 `>`。
- `always_comb` 中 `rresp` 的默认赋值被注释掉；`rdata` 只在函数内部被赋值。
- `raddr_dec` 用 `rdlen_count == arlen`，`rvalids` 用 `rdlen_count_next == arlen-1`。
- `data_wr_*`/`data_rd_*` 里 `memory[addr+i]`，i 到 3，addr 到 127 时越界。
- `bwait` 状态从 `bidle` 无法到达，且条件写反。

> 提醒：这些是"看代码得来的怀疑"，不是结论。每一条都要用一次仿真去证实或推翻，
> 证伪的也要写进报告——不然你只是换了个方式读代码。

---

## 11. 附：AXI3 关键约束速查

- VALID 不得等 READY；READY 可以等 VALID（但会掉吞吐）
- 握手是"同一时钟沿 valid&ready 同时为高"，采样必须在时钟沿之后用 clocking block
- AWLEN 是"拍数-1"，不是拍数
- INCR 不得跨 4KB 边界
- WRAP 拍数只能是 2/4/8/16，起始地址按 size 对齐，在 size×拍数 的块内回绕
- WLAST / RLAST 各自只在一笔的最后一拍为高
- BID / RID 必须与对应请求的 ID 一致
- AXI3 的 W 通道带 WID，支持写交织；AXI4 已删除 WID
- SLVERR 表示从设备正常响应但业务出错；DECERR 表示地址解码失败
