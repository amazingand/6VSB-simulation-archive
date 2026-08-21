# 02_体系 / uncleaved · USAGE

> 本目录为 **uncleaved 体系(未切割态)** 的构型 PDB(参考结构)。与 cleaved 镜像同构,文件不可互换。
> 配套:根目录 `02_体系/PROGRESS.md`(自检摘要)、`02_体系/构建说明_v01.md`、
> `02_体系/自检报告_v01.md`、根 `NODES.md` §5(构型 X / uncleaved 定义)。

---

## construct_X_uncleaved_v01.pdb

- **用途**:构型 X 未切割态参考 PDB——S1 尾(PDB 540–685)与 S2 头(PDB 686–1035)由
  685–686 肽键共价连为单链;供结构核对与参考。
- **适用体系**:uncleaved 仅。
- **输入**:由 CHARMM-GUI archive 全长模型提取(缺失区已补齐),经几何自检。
- **输出**:无独立输出(参考结构,不参与运行)。
- **调用方式**:VMD / PyMOL / parmed 载入查看;或作 cpptraj 参考框架。
- **限制**:残基编号为 CHARMM-GUI 重排序号;不是 Amber 运行输入(parm7/rst7 由用户本地
  CHARMM-GUI 包持有);与 cleaved PDB 不可互换。
- **已知问题**:无。
