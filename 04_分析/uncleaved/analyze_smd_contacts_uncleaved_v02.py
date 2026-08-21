#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
analyze_smd_contacts_uncleaved_v02.py — 项目 C' 轨迹级接触分析(在本地 / 工作站运行)
======================================================================

对定量 SMD(1 Å/ns)的分片轨迹做**残基级接触演化**分析,回答机制报告
`05_对比/机制分析_v01.md` §7 待确认的问题:

  * 界面盐桥(ASP614–LYS854 / LYS557–ASP839)随解离的存活与断裂位置;
  * S1 尾哪些残基在哪些 COM 距离窗口仍与 S2 头有接触(承力残基映射);
  * 二次抗阻带(cleaved 36–45 Å / uncleaved 37.5–42.5 Å)的接触特征。

输入全部与 M3 生产一致,无需额外处理:在 amber/ 目录内(或 --traj 指向
smd_production/)给出 prmtop / step3_input.pdb / smd_uncleaved_v02.RST / smd_chunk*.nc。
部分分片即可运行(按 COM 距离自动分窗, 未推的窗口留空)。

用法:
  python analyze_smd_contacts_uncleaved_v02.py --traj "smd_production/smd_chunk*.nc"
         --forces smd_production/smd.out --eq4 eq4_npt.rst7
         --windows 31.3-37.5,37.5-42.5,42.5-45,45-55 --out contacts_uncleaved

依赖(AmberTools 自带): parmed, netCDF4, numpy, matplotlib。
RST 的 igr1/igr2 定义两个界面组(与 pmemd COM 约束同一原子组),COM 距离即反应坐标。

产物:
  <out>_saltbridges.tsv       逐帧盐桥距离(按 COM 距离排列)
  <out>_windows.tsv           按窗口: 力 / 盐桥形成占比 / 帧数
  <out>_residue_contacts.tsv  S1 尾残基 × 窗口 接触矩阵
  <out>_saltbridges.png  <out>_contact_map.png  <out>_window_forces.png
======================================================================
"""
import argparse, glob, os, re, sys
import numpy as np

K_PN = 69.478  # 1 kcal/mol/Å = 69.478 pN


# ---------------- 命令行 ----------------
def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("system", nargs="?", default="uncleaved", choices=["uncleaved"],
                   help="体系(固定 uncleaved; 决定默认 RST / 盐桥对 / 窗口)")
    p.add_argument("--top", default="step3_input.parm7", help="prmtop")
    p.add_argument("--pdb", default="step3_input.pdb",
                   help="CHARMM-GUI PDB(原子顺序与 prmtop 一致, 保留 PDB 残基编号)")
    p.add_argument("--rst", default=None, help="反应坐标 RST(默认 smd_<system>.RST)")
    p.add_argument("--traj", default="smd_chunk*.nc",
                   help="分片轨迹 glob(默认 smd_chunk*.nc; 生产在 smd_production/ 下)")
    p.add_argument("--eq4", default="eq4_npt.rst7",
                   help="平衡末态 rst7(原生接触参考; 缺省用轨迹首帧)")
    p.add_argument("--forces", default="smd.out",
                   help="合并 DUMPAVE(力/功; 缺省 smd.out, 可省略)")
    p.add_argument("--cutoff", type=float, default=4.5,
                   help="接触判据: 任一重原子对 < cutoff Å (默认 4.5)")
    p.add_argument("--sb-cutoff", type=float, default=4.0,
                   help="盐桥判据: O…N < 此值视为形成 (默认 4.0)")
    p.add_argument("--windows", default=None,
                   help="窗口列表, 逗号分隔 'a-b'(默认按体系机制窗口)")
    p.add_argument("--sb", default=None,
                   help="追加盐桥对, 逗号分隔 'ASP614:LYS854'(顺序不限, 自动判定酸性O/碱性N)")
    p.add_argument("--max-frames", type=int, default=60,
                   help="每窗口接触采样上限帧数 (默认 60)")
    p.add_argument("--out", default=None, help="输出前缀 (默认 contacts_<system>)")
    p.add_argument("--no-plot", action="store_true", help="不画图")
    return p.parse_args()


# ---------------- 原子元数据 ----------------
def load_atoms(pdb_path, parm):
    """解析 step3_input.pdb(原子顺序与 prmtop 一致), 1-based 索引 → 元数据。
    重原子判定用 prmtop 原子质量(权威)。"""
    seg, rn, rname, aname = [], [], [], []
    for ln in open(pdb_path):
        if ln.startswith(("ATOM", "HETATM")):
            seg.append(ln[72:76].strip())
            rn.append(int(ln[22:26]))
            rname.append(ln[17:20].strip())
            aname.append(ln[12:16].strip())
    masses = np.array([at.mass for at in parm.atoms])
    assert len(seg) == len(masses), "step3_input.pdb 与 prmtop 原子数不一致"
    return {"seg": seg, "resnum": rn, "resname": rname, "aname": aname,
            "heavy": masses > 1.5, "natom": len(seg)}


def label_to_atoms(label, atoms):
    """'ASP614' 或 'PROC:ASP614' → (重原子, 侧链酸性O, 侧链碱性N) 的 1-based 索引。"""
    if ":" in label:
        segpart, rest = label.split(":", 1)
    else:
        segpart, rest = None, label
    m = re.match(r"([A-Za-z]{3})([0-9]+)$", rest)
    if not m:
        raise SystemExit(f"错误: 残基标签 '{label}' 应为 'ASP614' 或 'PROC:ASP614'")
    rname_want, rnum = m.group(1), int(m.group(2))
    acid = {"ASP": {"OD1", "OD2"}, "GLU": {"OE1", "OE2"}}.get(rname_want, set())
    base = {"LYS": {"NZ"}, "ARG": {"NH1", "NH2"}}.get(rname_want, set())
    idx_heavy, idx_acid, idx_base = [], [], []
    for i in range(atoms["natom"]):
        if atoms["resname"][i] != rname_want or atoms["resnum"][i] != rnum:
            continue
        if segpart and atoms["seg"][i] != segpart:
            continue
        if not atoms["heavy"][i]:
            continue
        an = atoms["aname"][i]
        idx_heavy.append(i + 1)
        if an in acid:
            idx_acid.append(i + 1)
        if an in base:
            idx_base.append(i + 1)
    if not idx_heavy:
        raise SystemExit(f"错误: 未找到残基 {label}(查 step3_input.pdb 段/编号)")
    # 固定 int 类型: np.array([]) 默认 float64, 混入拼接会让索引数组变浮点(空酸/碱侧时)
    return (np.array(idx_heavy, dtype=int),
            np.array(idx_acid, dtype=int),
            np.array(idx_base, dtype=int))


def parse_rst_igr(rst_path):
    txt = open(rst_path).read()
    def nums(block):
        return [int(x) for x in re.split(r"[,\s]+", block) if x.strip().isdigit()]
    return (np.array(nums(re.findall(r"igr1\s*=\s*(.*?)igr2", txt, re.S)[0])),
            np.array(nums(re.findall(r"igr2\s*=\s*(.*?)\s*&end", txt, re.S)[0])))


def parse_windows(s, system):
    if s:
        return [tuple(map(float, tok.split("-"))) for tok in s.split(",")]
    return ([(28.0, 31.6), (31.6, 36.0), (36.0, 45.0), (45.0, 55.0)] if system == "cleaved"
            else [(31.3, 37.5), (37.5, 42.5), (42.5, 45.0), (45.0, 55.0)])


def default_sb_pairs(system):
    return {"cleaved": ["ASP614:LYS854", "LYS557:ASP839"],
            "uncleaved": ["ASP614:LYS854"]}[system]


# ---------------- 轨迹读取 ----------------
def read_nc(ds, atom_idx, frame_list):
    """读 netCDF 轨迹指定帧、指定原子(1-based)。返回 (nfr, len(idx), 3)。"""
    v = ds.variables["coordinates"]
    return v[np.asarray(frame_list, dtype=int), :, :][:, np.asarray(atom_idx, dtype=int) - 1, :]


def read_rst7_coords(path, atom_idx=None):
    from parmed import load_file
    st = load_file(path)
    crd = st.coordinates
    if crd.ndim == 3:
        crd = crd[0]
    if atom_idx is not None:
        crd = crd[np.asarray(atom_idx) - 1]
    return crd


# ---------------- 接触计算 ----------------
def residue_contacts_frame(s1_crd, s2_crd, res_of_row, cutoff):
    """单帧: 每个 S1 残基是否有重原子与任一 S2 重原子接触。
    s1_crd: (nS1_heavy, 3); res_of_row: 每个重原子行 → 残基组号。"""
    out = np.zeros(int(res_of_row.max()) + 1, dtype=bool)
    step = 256
    for i0 in range(0, len(s1_crd), step):
        a = s1_crd[i0:i0 + step]
        d2 = ((a[:, None, :] - s2_crd[None, :, :]) ** 2).sum(-1)
        hit = (d2 < cutoff ** 2).any(1)
        for k, ii in enumerate(range(i0, min(i0 + step, len(s1_crd)))):
            if hit[k]:
                out[res_of_row[ii]] = True
    return out


# ---------------- 绘图 ----------------
def pick_cjk_font():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.font_manager as fm
    for f in ["Noto Sans CJK SC", "Noto Sans CJK JP", "WenQuanYi Zen Hei", "AR PL UMing CN"]:
        try:
            fm.findfont(f, fallback_to_default=False)
            return f
        except Exception:
            continue
    return None


def plot_saltbridges(com, sb, labels, path):
    import matplotlib.pyplot as plt
    f = pick_cjk_font()
    if f:
        plt.rcParams["font.sans-serif"] = [f]
    plt.rcParams["axes.unicode_minus"] = False
    n = sb.shape[1]
    colors = ["#0072B2", "#E69F00", "#009E73", "#D55E00"]
    fig, axes = plt.subplots(n, 1, figsize=(8, 2.4 * n), sharex=True, squeeze=False)
    for k, ax in enumerate(axes[:, 0]):
        ax.plot(com, sb[:, k], color=colors[k % 4], lw=0.8)
        ax.axhline(4.0, color="#888888", lw=0.8, ls="--")
        ax.set_ylim(0, 15)
        ax.set_ylabel("O…N (Å)")
        ax.set_title(labels[k], fontsize=10, loc="left")
    axes[-1, 0].set_xlabel("S1尾↔S2头 COM 距离 (Å)")
    fig.suptitle("界面盐桥随解离演化(判据 4.0 Å)", fontsize=12)
    fig.tight_layout(rect=[0, 0, 1, 0.97])
    fig.savefig(path, dpi=200)
    plt.close(fig)
    print(f"  → {path}")


def plot_contact_map(mat, resnums, windows, forces, key_res, path):
    import matplotlib.pyplot as plt
    from matplotlib.colors import Normalize
    f = pick_cjk_font()
    if f:
        plt.rcParams["font.sans-serif"] = [f]
    plt.rcParams["axes.unicode_minus"] = False
    data = np.ma.masked_invalid(mat)
    fig, ax = plt.subplots(figsize=(11, 3.8))
    im = ax.imshow(data, aspect="auto", cmap="YlGnBu", norm=Normalize(0, 1), origin="lower")
    fig.colorbar(im, ax=ax, pad=0.02).set_label("与 S2 头接触帧占比")
    yl = [f"{a:.1f}–{b:.1f} Å" for a, b in windows]
    if forces is not None:
        yl = [f"{s}\n均力 {f0:.0f} pN" if f0 == f0 else s for s, f0 in zip(yl, forces)]
    ax.set_yticks(range(len(windows)))
    ax.set_yticklabels(yl, fontsize=8)
    step = max(1, len(resnums) // 20)
    ticks = list(range(0, len(resnums), step))
    ax.set_xticks(ticks)
    ax.set_xticklabels([str(resnums[i]) for i in ticks], fontsize=8)
    for r in key_res:
        if r in resnums:
            ax.axvline(resnums.index(r) - 0.5, color="#888888", lw=0.6, ls=":")
    ax.set_xlabel("S1 尾残基 (PDB 编号 540–685)")
    ax.set_title("S1 尾残基接触图(按 COM 窗口; 虚线=关键残基)")
    fig.tight_layout()
    fig.savefig(path, dpi=200)
    plt.close(fig)
    print(f"  → {path}")


def plot_window_forces(windows, forces, path):
    import matplotlib.pyplot as plt
    f = pick_cjk_font()
    if f:
        plt.rcParams["font.sans-serif"] = [f]
    plt.rcParams["axes.unicode_minus"] = False
    fig, ax = plt.subplots(figsize=(7, 3.0))
    x = np.arange(len(windows))
    ax.bar(x, forces, color="#0072B2", width=0.6)
    ax.set_xticks(x)
    ax.set_xticklabels([f"{a:.0f}–{b:.0f}" for a, b in windows])
    ax.set_xlabel("COM 距离窗口 (Å)")
    ax.set_ylabel("窗口平均力 (pN)")
    ax.set_title("各 COM 窗口平均持续力")
    for xi, fi in zip(x, forces):
        if fi == fi:
            ax.text(xi, fi, f"{fi:.0f}", ha="center", va="bottom", fontsize=8)
    fig.tight_layout()
    fig.savefig(path, dpi=200)
    plt.close(fig)
    print(f"  → {path}")


# ---------------- 主流程 ----------------
def main():
    args = parse_args()
    out = args.out or "contacts_uncleaved"
    rst = args.rst or "smd_uncleaved_v02.RST"
    print(f"==> 体系 {args.system}, 输出前缀 {out}")

    for fp in (args.top, args.pdb, rst):
        if not os.path.exists(fp):
            raise SystemExit(f"错误: 缺 {fp}(在 amber/ 目录运行, 或用 --top/--pdb/--rst 指定)")
    traj_files = sorted(glob.glob(args.traj))
    if not traj_files:
        raise SystemExit(f"错误: 轨迹 glob '{args.traj}' 未匹配任何文件")

    from parmed import load_file
    import netCDF4
    parm = load_file(args.top)
    atoms = load_atoms(args.pdb, parm)
    igr1, igr2 = parse_rst_igr(rst)
    print(f"==> igr1 = {len(igr1)} Cα, igr2 = {len(igr2)} Cα")

    # ---- 盐桥对 ----
    sb_pairs = list(default_sb_pairs(args.system))
    if args.sb:
        sb_pairs += [s.strip() for s in args.sb.split(",") if s.strip()]
    sb_info = []
    for lab in sb_pairs:
        r1, r2 = lab.split(":")
        _, aO1, bN1 = label_to_atoms(r1, atoms)
        _, aO2, bN2 = label_to_atoms(r2, atoms)
        # 按原子角色自动判定 O(酸)…N(碱), 与标签先后无关:
        #   'ASP614:LYS854' → o=ASP614 的 OD1/OD2, n=LYS854 的 NZ
        #   'LYS557:ASP839' → o=ASP839 的 OD1/OD2, n=LYS557 的 NZ(此前误退化为残基级任意重原子接触)
        o_idx = np.concatenate([aO1, aO2])
        n_idx = np.concatenate([bN1, bN2])
        if not len(o_idx):
            raise SystemExit(f"错误: 盐桥对 {lab} 未找到酸性 O(ASP/GLU 的 OD/OE)")
        if not len(n_idx):
            raise SystemExit(f"错误: 盐桥对 {lab} 未找到碱性 N(LYS/ARG 的 NZ/NH)")
        sb_info.append((lab, o_idx, n_idx))
    all_sb_idx = np.unique(np.concatenate([np.concatenate([o, n]) for _, o, n in sb_info])) \
        if sb_info else np.array([], dtype=int)
    sb_col = {int(a): j for j, a in enumerate(all_sb_idx)}

    # ---- S1 尾 / S2 头(接触图) ----
    # 注意: 两体系链命名不同(cleaved: S1尾在 PROC、S2头在 PROA+PROB;
    # uncleaved: S1尾在 PROB、S2头全在 PROA), 硬编码 seg=="PROC" 会在 uncleaved
    # 返回空 S1 尾(报 '0 残基/0 重原子')。一律按残基号 + 蛋白链定位构型区:
    seg = atoms["seg"]; rn = atoms["resnum"]; heavy = atoms["heavy"]
    is_prot = np.array([seg[i].startswith("PRO") for i in range(atoms["natom"])])
    s1_sel = np.array([i for i in range(atoms["natom"])
                       if heavy[i] and is_prot[i] and 540 <= rn[i] <= 685])
    s2_sel = np.array([i for i in range(atoms["natom"])
                       if heavy[i] and is_prot[i] and 686 <= rn[i] <= 1035])
    if not len(s1_sel) or not len(s2_sel):
        raise SystemExit("错误: 未按残基号定位到 S1尾(540–685)/S2头(686–1035)重原子")
    s1_heavy = s1_sel + 1          # 1-based, 供轨迹索引
    s2_heavy = s2_sel + 1
    s1_resnums = sorted(set(int(rn[i]) for i in s1_sel))
    s1_res_idx = [np.array([i + 1 for i in s1_sel if rn[i] == r], dtype=int)
                  for r in s1_resnums]
    res_of_row = np.repeat(np.arange(len(s1_res_idx)), [len(x) for x in s1_res_idx])
    print(f"==> S1 尾 {len(s1_res_idx)} 残基/{len(s1_heavy)} 重原子; S2 头 {len(s2_heavy)} 重原子")

    windows = parse_windows(args.windows, args.system)
    print(f"==> 窗口: {', '.join(f'{a:.1f}–{b:.1f}' for a, b in windows)}")

    # ---- 力表 ----
    forces_tab = None
    if os.path.exists(args.forces):
        rows = []
        for ln in open(args.forces):
            parts = ln.split()
            if len(parts) >= 3 and parts[1].replace(".", "", 1).isdigit():
                rows.append((round(float(parts[1]), 2), float(parts[2])))
        forces_tab = dict(rows)
        print(f"==> 力表: {len(rows)} 行 ({args.forces})")

    # ---- eq4 原生接触 ----
    native = None
    if os.path.exists(args.eq4):
        eq4 = read_rst7_coords(args.eq4)
        frac = residue_contacts_frame(eq4[np.asarray(s1_heavy) - 1],
                                      eq4[np.asarray(s2_heavy) - 1], res_of_row, args.cutoff)
        native = frac.astype(float)
        print(f"==> eq4 原生接触: {int(native.sum())}/{len(native)} 个 S1 残基与 S2 头接触")

    # ---- 第一遍: COM + 盐桥(全部帧) ----
    # igr1/igr2 不相交(144+200=344 Cα), 直接拼接保序, 前 len(igr1) 列 = igr1
    igr_combo = np.concatenate([igr1, igr2])
    com_list, sb_list, bounds = [], [], []
    g0 = 0
    for f in traj_files:
        ds = netCDF4.Dataset(f)
        nfr = ds.dimensions["frame"].size
        c = ds.variables["coordinates"][:, np.asarray(igr_combo) - 1, :]
        c1 = c[:, :len(igr1)].mean(1)
        c2 = c[:, len(igr1):].mean(1)
        com = np.sqrt(((c1 - c2) ** 2).sum(1))
        com_list.append(com)
        if len(all_sb_idx):
            csb = ds.variables["coordinates"][:, np.asarray(all_sb_idx) - 1, :]
            cols = []
            for _, o, n in sb_info:
                op = np.array([sb_col[int(a)] for a in o])
                np_ = np.array([sb_col[int(a)] for a in n])
                d2 = ((csb[:, op][:, :, None, :] - csb[:, np_][:, None, :, :]) ** 2).sum(-1)
                # d2 是平方距离, 报告/比较前必须开方, 否则数值是 Å²(此前 bug: 7.31 实为 2.70²)
                cols.append(np.sqrt(d2.min(axis=(1, 2))))
            sb_list.append(np.column_stack(cols))
        bounds.append((f, g0, g0 + nfr))
        g0 += nfr
        ds.close()
    com_all = np.concatenate(com_list)
    sb_all = np.concatenate(sb_list, axis=0) if sb_list else np.zeros((len(com_all), 0))
    print(f"==> {len(traj_files)} 分片, {len(com_all)} 帧; COM {com_all.min():.2f}–{com_all.max():.2f} Å")

    # ---- 盐桥输出 ----
    if sb_all.shape[1]:
        with open(f"{out}_saltbridges.tsv", "w") as fo:
            fo.write("COM_A\t" + "\t".join(sb_pairs) + "\n")
            for i in range(len(com_all)):
                fo.write(f"{com_all[i]:.3f}\t" + "\t".join(f"{v:.2f}" for v in sb_all[i]) + "\n")
        print(f"  → {out}_saltbridges.tsv")

    # ---- 第二遍: 每窗口采样接触 ----
    mat = np.full((len(windows), len(s1_res_idx)), np.nan)
    win_force = np.full(len(windows), np.nan)
    win_nf, win_sb = np.zeros(len(windows), int), []
    for wi, (wa, wb) in enumerate(windows):
        sel = np.where((com_all >= wa) & (com_all < wb))[0]
        win_nf[wi] = len(sel)
        if len(sel):
            fv = np.array([forces_tab.get(round(com_all[i], 2), np.nan) for i in sel]) \
                if forces_tab else np.array([np.nan] * len(sel))
            fv = fv[fv == fv]
            win_force[wi] = fv.mean() * K_PN if len(fv) else np.nan
            win_sb.append([float((sb_all[sel, j] < args.sb_cutoff).mean())
                           for j in range(sb_all.shape[1])])
        else:
            win_sb.append([])
        if not len(sel):
            continue
        sel_s = sel[np.linspace(0, len(sel) - 1, min(len(sel), args.max_frames)).astype(int)]
        acc = np.zeros(len(s1_res_idx))
        cnt = 0
        for gi in sel_s:
            cf = next((b for b in bounds if b[1] <= gi < b[2]), None)
            if cf is None:
                continue
            f, gs, _ = cf
            ds = netCDF4.Dataset(f)
            c_s1 = read_nc(ds, s1_heavy, [gi - gs])[0]
            c_s2 = read_nc(ds, s2_heavy, [gi - gs])[0]
            ds.close()
            acc += residue_contacts_frame(c_s1, c_s2, res_of_row, args.cutoff).astype(float)
            cnt += 1
        if cnt:
            mat[wi] = acc / cnt

    # ---- 窗口汇总 ----
    with open(f"{out}_windows.tsv", "w") as fo:
        fo.write("window_start\twindow_end\tn_frames\tavg_force_pN\t" +
                 "\t".join(f"sb_{p}_formed" for p in sb_pairs) + "\n")
        for wi, (wa, wb) in enumerate(windows):
            fo.write(f"{wa:.2f}\t{wb:.2f}\t{win_nf[wi]}\t{win_force[wi]:.1f}\t" +
                     "\t".join(f"{v:.3f}" for v in win_sb[wi]) + "\n")
    print(f"  → {out}_windows.tsv")

    # ---- 接触矩阵输出 ----
    with open(f"{out}_residue_contacts.tsv", "w") as fo:
        fo.write("resnum\t" + "\t".join(f"w{wa:.0f}-{wb:.0f}" for wa, wb in windows) + "\n")
        for j, rn in enumerate(s1_resnums):
            row = [f"{mat[wi, j]:.3f}" if mat[wi, j] == mat[wi, j] else "NA"
                   for wi in range(len(windows))]
            fo.write(f"{rn}\t" + "\t".join(row) + "\n")
    print(f"  → {out}_residue_contacts.tsv")

    # ---- 打印汇总 ----
    resname_by_num = {rn: atoms["resname"][int(s1_res_idx[j][0]) - 1]
                      for j, rn in enumerate(s1_resnums)}
    print("\n==== 汇总(残基级接触, 采样占比) ====")
    for wi, (wa, wb) in enumerate(windows):
        fstr = f"均力={win_force[wi]:.0f} pN" if win_force[wi] == win_force[wi] else "力 N/A"
        line = f"窗口 {wa:.1f}–{wb:.1f} Å: {fstr}; "
        m = mat[wi]
        if np.isnan(m).all():
            print(line + "无帧"); continue
        hot = np.where(m > 0.5)[0]
        top = np.argsort(-m)[:5]
        line += (f"{len(hot)} 残基接触>50%; Top: " +
                 ", ".join(f"{resname_by_num[s1_resnums[j]]}{s1_resnums[j]}({m[j]:.2f})"
                           for j in top if m[j] == m[j]))
        print(line)
    print("\n完成。TSV 用表格软件打开; 图在 *.png。")

    # ---- 绘图 ----
    if not args.no_plot:
        if sb_all.shape[1]:
            plot_saltbridges(com_all, sb_all, sb_pairs, f"{out}_saltbridges.png")
        plot_contact_map(mat, s1_resnums, windows,
                         None if np.isnan(win_force).all() else win_force,
                         [540, 557, 614, 616, 685], f"{out}_contact_map.png")
        if not np.isnan(win_force).all():
            plot_window_forces(windows, win_force, f"{out}_window_forces.png")


if __name__ == "__main__":
    main()
