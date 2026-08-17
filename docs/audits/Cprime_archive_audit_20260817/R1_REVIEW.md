# R1 历史压缩包独立复核

复核日期：2026-08-17

结论：`WARNING`，W1 机械审计可信，W2 可以按白名单继续；未发现错误覆盖。

## 完整性复核

- 13 个物理压缩包、9 个唯一容器；容器大小、SHA-256 和成员数无不一致。
- 348 条解压文件记录与磁盘文件一一对应；重新计算大小和 SHA-256 后无不一致。
- 精确重复容器组 4 个、重复文件内容组 112 个、同规范路径异内容组 62 个。
- 62 个路径差异均来自系统或版本命名空间差异；没有同一系统、同一阶段、同一规范目标的意外分叉。

## 权威来源

| 阶段 | 权威来源 SHA-256 |
|---|---|
| P3 cleaved | `2d68fc708a32101691e7abddde3ca4c1e65554a7272c7186a9df379bab935363` |
| P3 uncleaved | `d338a100947a70bdb3981e38a504fee4fa99bd9ddb8f0f1f2840ecc520318143` |
| P3 core | `3d5bdec39c6de7bfbbdeea2d6f1b1b74fd4a9e938b2743ecb949bee20ea677c3` |
| P4 final | `82de76be417b85dc7ffa4b14a5d190f347c16dded323ace376a4c1b63a8c2637` |
| P4 earlier metadata variant | `bc48c181aec43e1781e8bc1d55e6958d7626916c6946919e59aa4e480283411c` |

两个大型 construct-X 来源容器只建立清单和当前路径映射，不在 `archive/` 再复制其展开内容。

## Unresolved

唯一无法确认阶段归属的文件：

- 文件名：`analyze_smd.py`
- SHA-256：`63cdce37976d404943901f8a98cea36d0f43613622bc3eb7ecebeebb2bd9a842`
- 来源：两个 P2-derived hybrid 容器
- 处理：只保留一份于 `archive/unresolved/U1_analyze_smd_63cdce37/`，附来源清单；不得标记为 P1、P2 或 P3。

## W2 白名单

- P1 说明；
- 整合包中的 P2 重建目录；
- 三个 P3 权威容器的展开树；
- P4 final 展开树及 P4 较早说明变体；
- 两个大型原始来源的成员/来源清单；
- 唯一 unresolved 文件的隔离副本。

压缩包删除、历史重写和 Git LFS 清理均不属于本轮 W2。
