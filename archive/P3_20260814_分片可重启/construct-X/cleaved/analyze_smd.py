#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
analyze_smd.py — 解析 SMD(DUMPAVE)输出,绘制力-位移 / 拉力-时间 / 做功曲线。

DUMPAVE 文件(pmdemd/pmemd.cuda jar=1 模式)每 DUMPFREQ 步一行,4 列:
  1. 约束目标位置 r2(Å)  —— 恒速拉动下随时间线性推进,【不是时间】
  2. 实际 COM 距离(Å)     —— 两基团质心的真实距离(反应坐标)
  3. 约束弹簧力(kcal/mol/Å) = 2·rk2·Δr(rk2 = 7.2)
  4. 累计功(kcal/mol)     —— 单段内累计;分片运行时各段从 0 重启,本脚本自动跨段累计

run_smd.sh 分片运行把各段 smd_chunkNN.out 按序合并成 smd.out(目标位置连续),
本脚本据此由目标位置/拉速反推时间,并把各段功拼接成全程累计功。

用法:
  python analyze_smd.py smd.out [--speed 5] [--plot] [--out smd_curves]
    --speed 5  拉速(Å/ns),用于由目标位置反推时间:5 Å/ns 初筛 / 1 Å/ns 定量
    --plot     生成 2×2 曲线图(smd_curves.png)

依赖: numpy, matplotlib(中文图需系统含 CJK 字体,见脚本内 FONT 配置)
"""
import sys, os
import numpy as np

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    HAS_PLT = True
except ImportError:
    HAS_PLT = False

# --- 中文字体:按系统可用字体设置;若全是豆腐块,安装 fonts-noto-cjk 后重试
FONT = "Noto Sans CJK SC"
try:
    import matplotlib.font_manager as fm
    fams = {f.name for f in fm.fontManager.ttflist}
    if FONT not in fams:
        import subprocess
        out = subprocess.run(["fc-list", ":lang=zh", "-f", "%{family}\\n"],
                             capture_output=True, text=True).stdout
        cand = [l.strip() for l in out.splitlines() if l.strip()]
        if cand:
            FONT = cand[0]
            print(f"[字体] 使用 {FONT}")
except Exception:
    pass
if HAS_PLT:
    matplotlib.rcParams["font.sans-serif"] = [FONT, "DejaVu Sans"]
    matplotlib.rcParams["axes.unicode_minus"] = False

R0 = 28.80            # SMD 起始目标距离(Å),与 smd.RST r2 一致
KCAL_TO_PN = 69.48    # 1 kcal/mol/Å ≈ 69.48 pN


def parse(path):
    """读 DUMPAVE,返回 (r2_target, dist, force, work)。跳过无法解析的行。"""
    r2, d, f, w = [], [], [], []
    with open(path) as fh:
        for line in fh:
            toks = line.split()
            if len(toks) < 4:
                continue
            try:
                vals = [float(x) for x in toks[:4]]
            except ValueError:
                continue
            r2.append(vals[0]); d.append(vals[1])
            f.append(vals[2]);  w.append(vals[3])
    if not r2:
        raise SystemExit(f"错误: {path} 未解析出数据行。请确认 smd_pull.mdin 含 "
                         "&wt type='DUMPFREQ' 使 DUMPAVE 有输出。")
    return (np.array(r2), np.array(d), np.array(f), np.array(w))


def derive_time(r2, speed):
    """由目标位置反推时间(ps): t = (r2 - R0) / v。speed 单位 Å/ns。"""
    return (r2 - R0) / (speed * 1e-3)


def cumulative_work(w):
    """分片合并后各段功从 0 重启,拼接为全程累计功。"""
    w = np.asarray(w, dtype=float)
    resets = np.where(np.diff(w) < -1.0)[0]      # 掉 1 kcal/mol 以上视为段边界
    cum = np.empty_like(w)
    offset, start = 0.0, 0
    for i in np.append(resets, len(w) - 1):
        seg = w[start:i + 1]
        cum[start:i + 1] = seg - seg[0] + offset
        offset += seg[-1] - seg[0]
        start = i + 1
    return cum


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    path = sys.argv[1]
    plot = "--plot" in sys.argv
    outbase = "smd_curves"
    speed = 5.0
    for i, a in enumerate(sys.argv):
        if a == "--out" and i + 1 < len(sys.argv):
            outbase = sys.argv[i + 1]
        elif a == "--speed" and i + 1 < len(sys.argv):
            speed = float(sys.argv[i + 1])

    r2, d, f, w = parse(path)
    t = derive_time(r2, speed)
    wc = cumulative_work(w)
    fmax = float(np.abs(f).max())
    nseg = len(np.where(np.diff(w) < -1.0)[0]) + 1

    print(f"解析 {len(t)} 个数据点(拉速 {speed:.0f} Å/ns, {nseg} 段):")
    print(f"  目标距离    {r2[0]:.2f} → {r2[-1]:.2f} Å")
    print(f"  时间范围    {t[0]:.1f} – {t[-1]:.1f} ps (由目标位置反推)")
    print(f"  COM 距离    {d[0]:.2f} → {d[-1]:.2f} Å  (位移 {d[-1]-d[0]:.2f} Å)")
    print(f"  最大拉力    {fmax:.1f} kcal/mol/Å ≈ {fmax*KCAL_TO_PN:.0f} pN (COM 弹簧力)")
    print(f"  累计做功    {wc[-1]:.1f} kcal/mol ≈ {wc[-1]*4.184:.1f} kJ/mol")

    # 解离检测: 峰值力后首次回落至 30% 以下
    if len(f) > 20:
        fl = np.abs(f)
        i_max = int(np.argmax(fl))
        drop = np.where(fl[i_max:] < 0.3 * fl[i_max])[0]
        if len(drop) > 0:
            i_drop = i_max + int(drop[0])
            print(f"  解离峰值    力峰值位于 COM 距离 {d[i_max]:.2f} Å "
                  f"(时间 ≈ {t[i_max]:.0f} ps)")
            print(f"  解离完成    峰值后首次回落至 30% 以下, COM 距离 ≈ "
                  f"{d[i_drop]:.2f} Å (时间 ≈ {t[i_drop]:.0f} ps)")

    # 保存曲线数据: 时间 目标r2 实际距离 力 累计功
    np.savetxt(f"{outbase}.dat", np.column_stack([t, r2, d, f, wc]),
               header="t_ps  r2_target_Ang  dist_Ang  "
                      "force_kcal_per_mol_per_Ang  work_cum_kcal_per_mol")

    if plot and HAS_PLT:
        fig, axes = plt.subplots(2, 2, figsize=(11, 8))
        axes[0, 0].plot(t, f, "-", lw=0.8, color="#1f77b4")
        axes[0, 0].set_xlabel("时间 (ps)"); axes[0, 0].set_ylabel("力 (kcal/mol/Å)")
        axes[0, 0].set_title("拉力-时间")
        axes[0, 1].plot(d, f, "-", lw=0.8, color="#1f77b4")
        axes[0, 1].set_xlabel("COM 距离 (Å)"); axes[0, 1].set_ylabel("力 (kcal/mol/Å)")
        axes[0, 1].set_title("力-位移")
        axes[1, 0].plot(t, wc, "-", lw=0.8, color="#d62728")
        axes[1, 0].set_xlabel("时间 (ps)"); axes[1, 0].set_ylabel("功 (kcal/mol)")
        axes[1, 0].set_title("累计做功-时间")
        axes[1, 1].plot(d, wc, "-", lw=0.8, color="#d62728")
        axes[1, 1].set_xlabel("COM 距离 (Å)"); axes[1, 1].set_ylabel("功 (kcal/mol)")
        axes[1, 1].set_title("累计做功-位移")
        for a in axes.flat:
            a.spines[["top", "right"]].set_visible(False)
            a.grid(alpha=0.3)
        fig.suptitle("SMD 力驱动解离曲线", fontsize=14)
        fig.tight_layout(rect=(0, 0, 1, 0.96))
        fig.savefig(f"{outbase}.png", dpi=200)
        print(f"[图] 已保存 {outbase}.png")
    elif plot and not HAS_PLT:
        print("[警告] 未装 matplotlib,跳过绘图(已保存 .dat)")


if __name__ == "__main__":
    main()
