# Cprime 历史结构重构任务图

| 节点 | 负责人 | 输入 | 输出 | 状态 | 完成条件 |
|---|---|---|---|---|---|
| P0 | Main | 用户决策、Git 基线 | `STATE.md`、`DECISIONS.md`、`TASKS.md`、代理配置 | DONE | 状态与约束已落盘 |
| E1 | Archive Explorer | 13 个物理压缩包 | 容器与安全性报告 | DONE | 9 组唯一内容、安全检查通过 |
| E2 | Archive Explorer | 整合包、`simulations/`、`protocols/` | 路径和 SHA-256 对应关系 | DONE | 现有规范文件与工作目录完成只读映射 |
| W1 | Archive Worker | E1/E2 清单 | 隔离解压树、成员清单、比较报告 | DONE | 无覆盖解压；每个成员有来源和 SHA-256 |
| R1 | Archive Reviewer | W1 输出 | 独立复核报告 | DONE | 重复、遗漏、冲突和 unresolved 分类可复现 |
| W2 | Main | R1 通过的结果 | `archive/`、`protocols/`、`analysis/`、来源映射 | DONE | 只写已确认映射；不删除压缩包 |
| V1 | Reviewer + Main | 正式结构 | Git diff、哈希、链接和上传范围验证 | DONE | 零意外文件、零哈希异常、可重新检出 |
| W3 | Main | V1 通过的分支 | commit、push、draft PR | TODO | 用户批准范围与远端 PR 一致 |

## Gate 规则

- `unresolved` 不得自动归入任一历史版本。
- 任一 SHA-256 不一致必须保留双方，禁止以名称相同判定重复。
- `W2` 开始前，`R1` 必须完成。
- 压缩包删除不属于当前 DAG；需另立决策和任务。
