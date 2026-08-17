#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
analyze_smd.py — 解析 SMD(DUMPAVE)输出,绘制拉力-时间/力-位移/做功曲线。

SMD 产物 smd.out(sander/pmemd DUMPAVE,jar=1 模式)每 ntpr 步一行,列为:
  时间(ps)  质心距离(Å)  约束力(kcal/mol/Å)  累计功(kcal/mol)
(不同 Amber 版本列略有差异,本脚本按 4 列通用解析并打印列头供核对)

用法:
  python analyze_smd.py smd.out [--plot] [--out smd_curves]

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

def parse(path):
    """读 DUMPAVE,返回 (t, dist, force, work)。跳过无法解析的行。"""
    t, d, f, w = [], [], [], []
    with open(path) as fh:
        for line in fh:
            toks = line.split()
            if len(toks) < 4:
                continue
            try:
                vals = [float(x) for x in toks[:4]]
            except ValueError:
                continue
            t.append(vals[0]); d.append(vals[1])
            f.append(vals[2]); w.append(vals[3])
    if not t:
        raise SystemExit(f"错误: {path} 未解析出数据行。若列数不同请检查 DUMPAVE 格式。")
    return (np.array(t), np.array(d), np.array(f), np.array(w))

def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    path = sys.argv[1]
    plot = "--plot" in sys.argv
    outbase = "smd_curves"
    for i, a in enumerate(sys.argv):
        if a == "--out" and i + 1 < len(sys.argv):
            outbase = sys.argv[i + 1]

    t, d, f, w = parse(path)
    print(f"解析 {len(t)} 个数据点:")
    print(f"  时间范围     {t[0]:.1f} – {t[-1]:.1f} ps")
    print(f"  COM 距离     {d[0]:.2f} → {d[-1]:.2f} Å  (位移 {d[-1]-d[0]:.2f} Å)")
    print(f"  最大拉力     {np.abs(f).max():.1f} kcal/mol/Å "
          f"(≈ {np.abs(f).max()*69.48:.0f} pN @ 单键)")
    print(f"  累计做功     {w[-1]-w[0]:.1f} kcal/mol "
          f"(≈ {(w[-1]-w[0])*4.184:.0f} kJ/mol)")

    # 力-位移 平台期判断: 寻找力骤降区(解离完成)
    if len(f) > 20:
        fl = np.abs(f)
        i_max = int(np.argmax(fl))
        tail = fl[i_max:]
        if len(tail) > 5 and tail[-1] < 0.3 * fl[i_max]:
            d_dissoc = d[i_max + np.argmin(tail)]
            print(f"  解离完成距离  ≈ {d_dissoc:.1f} Å(峰值力后首次回落)")

    # 保存曲线数据
    np.savetxt(f"{outbase}.dat", np.column_stack([t, d, f, w]),
               header="t_ps  dist_Ang  force_kcal_per_mol_per_Ang  work_kcal_per_mol")

    if plot and HAS_PLT:
        fig, axes = plt.subplots(2, 2, figsize=(11, 8))
        ax = axes[0, 0]; ax.plot(t, f, "-", lw=0.8); ax.set_xlabel("时间 (ps)"); ax.set_ylabel("力 (kcal/mol/Å)"); ax.set_title("拉力-时间")
        ax = axes[0, 1]; ax.plot(d, f, "-", lw=0.8); ax.set_xlabel("COM 距离 (Å)"); ax.set_ylabel("力 (kcal/mol/Å)"); ax.set_title("力-位移")
        ax = axes[1, 0]; ax.plot(t, w, "-", lw=0.8); ax.set_xlabel("时间 (ps)"); ax.set_ylabel("功 (kcal/mol)"); ax.set_title("累计做功-时间")
        ax = axes[1, 1]; ax.plot(d, w, "-", lw=0.8); ax.set_xlabel("COM 距离 (Å)"); ax.set_ylabel("功 (kcal/mol)"); ax.set_title("累计做功-位移")
        for a in axes.flat:
            a.spines[["top", "right"]].set_visible(False)
            a.grid(alpha=0.3)
        fig.suptitle("SMD 力驱动解离曲线", fontsize=14)
        fig.tight_layout(rect=(0, 0, 1, 0.96))
        fig.savefig(f"{outbase}.png", dpi=200)
        print(f"[图] 已保存 {outbase}.png")
    elif plot and not HAS_PLT:
        print("[警告] 未装 matplotlib,跳过绘图(已保存 {outbase}.dat)")

if __name__ == "__main__":
    main()
