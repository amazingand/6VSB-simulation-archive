# 02_体系 / cleaved · USAGE

> 本目录为 **cleaved 体系(切割态)** 的构型 PDB(参考结构)。配套:根目录
> `02_体系/PROGRESS.md`(自检摘要)、`02_体系/构建说明_v01.md`、`02_体系/自检报告_v01.md`、
> 根 `NODES.md` §5(构型 X / cleaved 定义)。

---

## construct_X_cleaved_v01.pdb

- **用途**:构型 X 切割态参考 PDB——S1 尾(PDB 540–685)+ S2 头(PDB 686–1035),furin
  685–686 断为两条链、S2 头在 S2′ 处断开;供结构核对、接触/盐桥几何参考与报告插图。
- **适用体系**:cleaved 仅。
- **输入**:由 CHARMM-GUI archive 全长模型提取(缺失区已补齐),经几何自检。
- **输出**:无独立输出(参考结构,不参与运行)。
- **调用方式**:VMD / PyMOL / parmed 载入查看;或作 cpptraj 参考框架。
- **限制**:残基编号为 CHARMM-GUI 重排序号(见 `自检报告_v01.md` 注);**不是** Amber 运行输入
  (parm7/rst7 由用户本地 CHARMM-GUI 包持有);与 uncleaved PDB 不可互换。
- **已知问题**:无。
