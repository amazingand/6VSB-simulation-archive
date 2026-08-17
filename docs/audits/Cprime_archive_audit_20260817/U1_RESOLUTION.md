# analyze_smd.py v0 归属处理记录

## 结论

SHA-256 为 `63cdce37976d404943901f8a98cea36d0f43613622bc3eb7ecebeebb2bd9a842` 的 `analyze_smd.py` 已确认是 v0 暂存草稿，不属于正式 v1→v2 交付链，也不是 P1–P4 的正式版本。

## 证据

- 版本确认报告：`docs/M3_analyze_smd版本迭代确认_v01.md`
- 迁移包内源报告 SHA-256：`66ed49aceb38992069ffaf3e548905ed5dfd27941cca4bb132f223c2512e0b95`
- 原 R1 结论：当时仅能确认它来自两个 P2-derived hybrid 传输容器，因此先隔离为 unresolved。

## 当前无压缩结构

- v0 草稿：`archive/non_delivery/analyze_smd_v0_63cdce37/analyze_smd.py`
- v1 正式文件：`archive/P3_20260814_分片可重启/construct-X/{cleaved,uncleaved}/analyze_smd.py`
- v2 正式文件：`archive/P4_20260815_核验修订/common/analyze_smd.py`
- 原传输容器的路径与 SHA-256：分别见各目录的 `SOURCE_ARCHIVES.tsv`

版本确认报告保留其形成时的原始路径表述；本文件记录重构后对应关系。
